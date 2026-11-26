// Provider service-catalogue service (Task 13.4).
// Orchestrates reference data, offerings, capabilities, pricing, locations,
// service areas, operating hours and exceptions. Every operation is authorized
// against the resolved provider context (individual ownership or active org
// membership + permission). IDOR-safe: access is never granted by id alone.
import { ForbiddenError, NotFoundError, ValidationError, ConflictError } from '../../shared/errors.js';
import * as authz from '../auth/authorization.service.js';
import { resolveProviderContext } from './provider.authorization.js';
import type { ProviderContext } from './provider.types.js';
import type {
  CreateExceptionInput,
  CreateLocationInput,
  CreateOfferingInput,
  CreateServiceAreaInput,
  OperatingHoursReplaceInput,
  UpdateExceptionInput,
  UpdateLocationInput,
  UpdateOfferingInput,
  UpdateServiceAreaInput,
} from './provider-catalogue.schemas.js';
import type { OfferingStatus, ServiceDomain } from './provider-catalogue.types.js';
import * as repo from './provider-catalogue.repository.js';

const ORG_MANAGER_ROLES = ['organization_owner', 'organization_admin'];

function domainForCategory(category: string): ServiceDomain | null {
  if (category.startsWith('moving_')) return 'moving';
  if (category.startsWith('garbage_')) return 'garbage';
  if (category.startsWith('laundry_')) return 'laundry';
  return null;
}

async function assertOrgCanManage(userId: string, organisationId: string, permission: string): Promise<void> {
  const roleIds = await authz.getUserOrganizationRoleIds(userId, organisationId);
  if (roleIds.some((r) => ORG_MANAGER_ROLES.includes(r))) return;
  if (await authz.hasPermission(userId, permission)) return;
  throw new ForbiddenError('Organization service-catalogue administration required');
}

// Authorize management of a specialized profile (individual owner or active org
// membership with the relevant permission).
async function assertCanManageProfile(
  context: ProviderContext,
  profileId: string,
  permission = 'provider.catalogue.manage',
): Promise<void> {
  if (context.individualProfileIds.includes(profileId)) return;
  if (context.organizationProfileIds.includes(profileId)) {
    // Resolve the owning organization for the profile.
    const org = await repoGetProfileOrg(profileId);
    if (!org) throw new ForbiddenError('Profile organization not found');
    await assertOrgCanManage(context.userId, org, permission);
    return;
  }
  throw new ForbiddenError('You may not manage this provider profile');
}

async function repoGetProfileOrg(profileId: string): Promise<string | null> {
  const { pool } = await import('../../db/pool.js');
  const r = await pool.query<{ organisation_id: string | null }>(
    `SELECT organisation_id FROM specialized_profiles WHERE id = $1`,
    [profileId],
  );
  return r.rows[0]?.organisation_id ?? null;
}

async function assertProfileInContext(context: ProviderContext, profileId: string): Promise<void> {
  if (!context.effectiveProfileIds.includes(profileId) && !context.organizationProfileIds.includes(profileId)) {
    throw new ForbiddenError('Profile is not in your provider context');
  }
}

// ---------------------------------------------------------------------------
// Reference data
// ---------------------------------------------------------------------------
export async function getCatalogue(domain?: ServiceDomain) {
  const [categories, capabilities] = await Promise.all([
    repo.listCategories(domain),
    repo.listCapabilities(domain),
  ]);
  return { categories, capabilities };
}

// ---------------------------------------------------------------------------
// Offerings
// ---------------------------------------------------------------------------
export async function listOfferings(
  userId: string,
  filters: { organizationId?: string | null; domain?: ServiceDomain; status?: OfferingStatus },
) {
  const context = await resolveProviderContext(userId, filters.organizationId ?? null);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  const profileIds = [...context.individualProfileIds, ...context.organizationProfileIds];
  return repo.listOfferings(profileIds, { domain: filters.domain, status: filters.status });
}

export async function getOffering(userId: string, serviceId: string) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertProfileInContext(context, offering.specializedProfileId);
  const [capabilities, pricing] = await Promise.all([
    repo.getOfferingCapabilities(serviceId),
    repo.getOfferingPricing(serviceId),
  ]);
  return { ...offering, capabilities, pricing };
}

export async function createOffering(userId: string, input: CreateOfferingInput) {
  const context = await resolveProviderContext(userId);
  await assertCanManageProfile(context, input.profileId);
  const category = await repo.findCategoryById(input.categoryId);
  if (!category) throw new ValidationError('Unknown or inactive service category');
  if (category.domain !== input.domain) throw new ValidationError('Category does not match the offering domain');
  // Guard against duplicate offerings (profile + category) with a friendly error.
  const existing = await repo.listOfferings([input.profileId], {});
  if (existing.some((o) => o.categoryId === input.categoryId)) {
    throw new ConflictError('An offering for this category already exists for this profile');
  }
  const offering = await repo.createOffering({
    specializedProfileId: input.profileId,
    domain: input.domain,
    categoryId: input.categoryId,
    title: input.title,
    description: input.description ?? null,
    serviceType: input.serviceType ?? null,
    status: input.status,
    config: input.config ?? {},
    createdBy: userId,
    capabilities: input.capabilities,
    pricing: input.pricing,
  });
  return getOffering(userId, offering.id);
}

export async function updateOffering(userId: string, serviceId: string, input: UpdateOfferingInput) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertCanManageProfile(context, offering.specializedProfileId);
  if (input.categoryId) {
    const category = await repo.findCategoryById(input.categoryId);
    if (!category || category.domain !== offering.domain) {
      throw new ValidationError('Category does not match the offering domain');
    }
    const siblings = await repo.listOfferings([offering.specializedProfileId], {});
    if (siblings.some((o) => o.categoryId === input.categoryId && o.id !== serviceId)) {
      throw new ConflictError('An offering for this category already exists for this profile');
    }
  }
  const updated = await repo.updateOffering(serviceId, input, userId);
  return getOffering(userId, updated?.id ?? serviceId);
}

const TRANSITIONS: Record<OfferingStatus, OfferingStatus[]> = {
  draft: ['active', 'archived'],
  active: ['paused', 'unavailable', 'archived'],
  paused: ['active', 'archived'],
  unavailable: ['active', 'archived'],
  archived: [],
};

export async function setOfferingStatus(
  userId: string,
  serviceId: string,
  action: 'activate' | 'pause' | 'archive',
  temp?: { from: string | null; to: string | null },
) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertCanManageProfile(context, offering.specializedProfileId);
  const hasWindow = Boolean(temp?.from || temp?.to);
  const target: OfferingStatus =
    action === 'activate' ? 'active' : action === 'archive' ? 'archived' : hasWindow ? 'unavailable' : 'paused';
  if (offering.status === target && !(action === 'pause' && hasWindow)) return getOffering(userId, serviceId);
  if (!TRANSITIONS[offering.status].includes(target)) {
    throw new ConflictError(`Cannot ${action} an offering in status ${offering.status}`);
  }
  if (action === 'pause' && temp?.to && temp?.from && temp.to < temp.from) {
    throw new ValidationError('Temporary closure end must be on/after start');
  }
  const updated = await repo.setOfferingStatus(
    serviceId,
    target,
    userId,
    action === 'pause' && hasWindow ? { from: temp?.from ?? null, to: temp?.to ?? null } : undefined,
  );
  return getOffering(userId, updated?.id ?? serviceId);
}

// ---- Capabilities & pricing ----
export async function getCapabilities(userId: string, serviceId: string) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertProfileInContext(context, offering.specializedProfileId);
  return repo.getOfferingCapabilities(serviceId);
}

export async function replaceCapabilities(userId: string, serviceId: string, caps: Array<{ capabilityId: string; enabled: boolean; detail?: string | null }>) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertCanManageProfile(context, offering.specializedProfileId);
  const valid = new Set((await repo.listCapabilities(offering.domain)).map((c) => c.id));
  for (const cap of caps) {
    if (!valid.has(cap.capabilityId)) throw new ValidationError(`Capability ${cap.capabilityId} is not valid for ${offering.domain}`);
  }
  await repo.replaceOfferingCapabilities(serviceId, caps);
  return repo.getOfferingCapabilities(serviceId);
}

export async function getPricing(userId: string, serviceId: string) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertProfileInContext(context, offering.specializedProfileId);
  return repo.getOfferingPricing(serviceId);
}

export async function setPricing(
  userId: string,
  serviceId: string,
  data: { pricingModel: string; currency: string; baseAmount?: number | null; minimumCharge?: number | null; unitLabel?: string | null; quotationRequired: boolean; isIndicative: boolean; priceNotes?: string | null },
) {
  const context = await resolveProviderContext(userId);
  const offering = await repo.findOfferingById(serviceId);
  if (!offering) throw new NotFoundError('Service offering not found');
  await assertCanManageProfile(context, offering.specializedProfileId);
  if (data.currency.toUpperCase() !== 'KES') {
    // Preserve the existing multi-currency architecture but default to KES.
  }
  return repo.upsertOfferingPricing(serviceId, { ...data, currency: data.currency.toUpperCase() });
}

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------
export async function listLocations(userId: string, organisationId?: string | null) {
  if (organisationId) {
    const isMember = await authz.isOrganizationMember(userId, organisationId);
    if (!isMember) throw new ForbiddenError('Organization membership required');
  }
  return repo.listLocations(userId, organisationId ?? null);
}

export async function createLocation(userId: string, input: CreateLocationInput) {
  if (input.organisationId) {
    await assertOrgCanManage(userId, input.organisationId, 'provider.locations.manage');
  }
  if (input.isPublic && input.locationType === 'personal_residential') {
    throw new ValidationError('A personal residential location cannot be public');
  }
  const visibility = input.isPublic ? 'public' : input.visibility === 'public' ? 'public' : 'private';
  return repo.createLocation({
    userId,
    specializedProfileId: input.specializedProfileId ?? null,
    organisationId: input.organisationId ?? null,
    locationType: input.locationType,
    label: input.label ?? null,
    latitude: input.latitude,
    longitude: input.longitude,
    formattedAddress: input.formattedAddress ?? null,
    placeId: input.placeId ?? null,
    country: input.country ?? null,
    county: input.county ?? null,
    city: input.city ?? null,
    neighbourhood: input.neighbourhood ?? null,
    street: input.street ?? null,
    buildingName: input.buildingName ?? null,
    locationSource: input.locationSource,
    isPublic: visibility === 'public',
    visibility,
    isPrimary: input.isPrimary,
  });
}

export async function updateLocation(userId: string, locationId: string, input: UpdateLocationInput) {
  const current = await repo.findLocationById(locationId);
  if (!current) throw new NotFoundError('Location not found');
  const owns = current.userId === userId;
  if (!owns) {
    if (!current.organisationId) throw new ForbiddenError('You may not edit this location');
    await assertOrgCanManage(userId, current.organisationId, 'provider.locations.manage');
  }
  if (input.isPublic && (input.locationType ?? current.locationType) === 'personal_residential') {
    throw new ValidationError('A personal residential location cannot be public');
  }
  const updated = await repo.updateLocation(locationId, input as Partial<repo.LocationData>, userId);
  return updated;
}

export async function deleteLocation(userId: string, locationId: string) {
  const current = await repo.findLocationById(locationId);
  if (!current) throw new NotFoundError('Location not found');
  const owns = current.userId === userId;
  if (!owns) {
    if (!current.organisationId) throw new ForbiddenError('You may not delete this location');
    await assertOrgCanManage(userId, current.organisationId, 'provider.locations.manage');
  }
  await repo.deleteLocation(locationId);
  return { id: locationId, deleted: true };
}

export async function setPrimaryLocation(userId: string, locationId: string) {
  const current = await repo.findLocationById(locationId);
  if (!current) throw new NotFoundError('Location not found');
  const owns = current.userId === userId;
  if (!owns) {
    if (!current.organisationId) throw new ForbiddenError('You may not edit this location');
    await assertOrgCanManage(userId, current.organisationId, 'provider.locations.manage');
  }
  return repo.setPrimaryLocation(locationId, userId);
}

// ---------------------------------------------------------------------------
// Service areas
// ---------------------------------------------------------------------------
export async function listServiceAreas(userId: string, profileId?: string | null, offeringId?: string | null) {
  const context = await resolveProviderContext(userId);
  if (profileId) {
    await assertProfileInContext(context, profileId);
    return repo.listServiceAreas([profileId], offeringId ?? null);
  }
  const profileIds = [...context.individualProfileIds, ...context.organizationProfileIds];
  return repo.listServiceAreas(profileIds, offeringId ?? null);
}

export async function createServiceArea(userId: string, input: CreateServiceAreaInput) {
  const context = await resolveProviderContext(userId);
  await assertCanManageProfile(context, input.specializedProfileId, 'provider.service_areas.manage');
  if (input.offeringId) {
    const offering = await repo.findOfferingById(input.offeringId);
    if (!offering || offering.specializedProfileId !== input.specializedProfileId) {
      throw new ValidationError('Offering does not belong to the profile');
    }
  }
  return repo.createServiceArea({
    specializedProfileId: input.specializedProfileId,
    offeringId: input.offeringId ?? null,
    country: input.country ?? null,
    county: input.county ?? null,
    city: input.city ?? null,
    neighbourhood: input.neighbourhood ?? null,
    areaDescription: input.areaDescription ?? null,
    latitude: input.latitude ?? null,
    longitude: input.longitude ?? null,
    radiusKm: input.radiusKm ?? null,
    isActive: input.isActive,
  });
}

export async function updateServiceArea(userId: string, areaId: string, input: UpdateServiceAreaInput) {
  const context = await resolveProviderContext(userId);
  const area = await repo.findServiceAreaById(areaId);
  if (!area) throw new NotFoundError('Service area not found');
  await assertCanManageProfile(context, area.specializedProfileId, 'provider.service_areas.manage');
  if (input.offeringId) {
    const offering = await repo.findOfferingById(input.offeringId);
    if (!offering || offering.specializedProfileId !== area.specializedProfileId) {
      throw new ValidationError('Offering does not belong to the profile');
    }
  }
  return repo.updateServiceArea(areaId, input as Partial<repo.ServiceAreaData>);
}

export async function deleteServiceArea(userId: string, areaId: string) {
  const context = await resolveProviderContext(userId);
  const area = await repo.findServiceAreaById(areaId);
  if (!area) throw new NotFoundError('Service area not found');
  await assertCanManageProfile(context, area.specializedProfileId, 'provider.service_areas.manage');
  await repo.deleteServiceArea(areaId);
  return { id: areaId, deleted: true };
}

// ---------------------------------------------------------------------------
// Operating hours & exceptions
// ---------------------------------------------------------------------------
export async function getAvailability(userId: string, profileId?: string | null, offeringId?: string | null) {
  const context = await resolveProviderContext(userId);
  const pid = profileId ?? null;
  if (pid) await assertProfileInContext(context, pid);
  return repo.listOperatingHours(pid, offeringId ?? null);
}

export async function replaceAvailability(userId: string, input: OperatingHoursReplaceInput) {
  const context = await resolveProviderContext(userId);
  const profileId = input.specializedProfileId ?? null;
  const offeringId = input.offeringId ?? null;
  if (profileId) await assertCanManageProfile(context, profileId, 'provider.availability.manage');
  else if (offeringId) {
    const offering = await repo.findOfferingById(offeringId);
    if (!offering) throw new NotFoundError('Service offering not found');
    await assertCanManageProfile(context, offering.specializedProfileId, 'provider.availability.manage');
  } else {
    throw new ValidationError('profileId or offeringId is required');
  }
  return repo.replaceOperatingHours(profileId, offeringId, input.timeZone, input.hours);
}

export async function listExceptions(userId: string, profileId: string, offeringId?: string | null) {
  const context = await resolveProviderContext(userId);
  await assertProfileInContext(context, profileId);
  return repo.listExceptions(profileId, offeringId ?? null);
}

export async function createException(userId: string, input: CreateExceptionInput) {
  const context = await resolveProviderContext(userId);
  await assertCanManageProfile(context, input.specializedProfileId, 'provider.availability.manage');
  return repo.createException({
    specializedProfileId: input.specializedProfileId,
    offeringId: input.offeringId ?? null,
    exceptionDate: input.exceptionDate,
    isUnavailable: input.isUnavailable,
    startTime: input.startTime ?? null,
    endTime: input.endTime ?? null,
    reason: input.reason ?? null,
    timeZone: input.timeZone,
  });
}

export async function updateException(userId: string, exceptionId: string, input: UpdateExceptionInput) {
  const context = await resolveProviderContext(userId);
  const current = await repo.findExceptionById(exceptionId);
  if (!current) throw new NotFoundError('Availability exception not found');
  await assertCanManageProfile(context, current.specializedProfileId, 'provider.availability.manage');
  return repo.updateException(exceptionId, input as Partial<repo.ExceptionData>);
}

export async function deleteException(userId: string, exceptionId: string) {
  const context = await resolveProviderContext(userId);
  const current = await repo.findExceptionById(exceptionId);
  if (!current) throw new NotFoundError('Availability exception not found');
  await assertCanManageProfile(context, current.specializedProfileId, 'provider.availability.manage');
  await repo.deleteException(exceptionId);
  return { id: exceptionId, deleted: true };
}

export { domainForCategory };