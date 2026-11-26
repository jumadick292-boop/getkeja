import type { Request, Response } from 'express';
import type { AuthUser } from '../auth/auth.types.js';
import { NotFoundError, ForbiddenError, ConflictError } from '../../shared/errors.js';
import * as repo from './landlord.repository.js';
import * as authz from '../auth/authorization.service.js';
import { findPropertyOwnerships, findPropertyAssignments } from '../auth/auth.repository.js';
import { transaction } from '../../db/tx.js';
import { enqueueSearchAlert } from '../house-seeker/search-alert.worker.js';
import { NotificationService } from '../auth/notification.service.js';
import * as lifecycle from '../site-visits/site-visit-lifecycle.js';
import * as messagingService from '../messaging/messaging.service.js';
import * as messagingRepo from '../messaging/messaging.repository.js';
import type { ConversationContextType } from '../messaging/messaging.repository.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function getParam(req: AuthenticatedRequest, name: string): string {
  const value = req.params[name];
  if (value === undefined) return '';
  return (Array.isArray(value) ? value[0] : value) as string;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

async function assertPropertyAccess(req: AuthenticatedRequest, propertyId: string, requiredPermission?: string) {
  const userId = assertAuth(req);
  // Basic property access (owner, assignment, unit access, org membership)
  const basic = await authz.canAccessProperty(userId, propertyId);
  if (!basic.allowed) throw new ForbiddenError(basic.reason);

  if (requiredPermission) {
    const ownerships = await findPropertyOwnerships(propertyId);
    const isOwner = ownerships.some((o) => o.userId === userId && o.status === 'active');

    if (!isOwner) {
      const hasPerm = await authz.hasPermission(userId, requiredPermission);
      if (!hasPerm) {
        throw new ForbiddenError(`Permission '${requiredPermission}' required`);
      }

      const assignments = await findPropertyAssignments(propertyId);
      const isManagerOrAgent = assignments.some(
        (a) =>
          a.userId === userId &&
          a.status === 'active' &&
          (a.assignment_type === 'property_manager' || a.assignment_type === 'letting_agent'),
      );

      if (!isManagerOrAgent) {
        throw new ForbiddenError('Insufficient property access for this action');
      }
    }
  }

  return basic;
}

async function assertUnitAccess(req: AuthenticatedRequest, unitId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessUnit(userId, unitId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

async function assertTenancyAccess(req: AuthenticatedRequest, tenancyId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessTenancy(userId, tenancyId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

function normalizeListing(listing: any): any {
  if (!listing) return listing;
  return {
    ...listing,
    rentAmount: listing.rentAmount !== undefined && listing.rentAmount !== null
      ? Number(listing.rentAmount)
      : listing.rentAmount,
    depositAmount: listing.depositAmount !== undefined && listing.depositAmount !== null
      ? Number(listing.depositAmount)
      : listing.depositAmount,
  };
}

// Valid enquiry status transitions.
const ENQUIRY_TRANSITIONS: Record<string, string[]> = {
  new: ['contacted', 'viewing_scheduled', 'closed', 'lost_declined'],
  contacted: ['viewing_scheduled', 'site_visit_scheduled', 'application_submitted', 'converted_to_tenant', 'closed', 'lost_declined'],
  viewing_scheduled: ['site_visit_scheduled', 'closed', 'lost_declined'],
  site_visit_scheduled: ['application_submitted', 'closed', 'lost_declined'],
  application_submitted: ['converted_to_tenant', 'closed', 'lost_declined'],
  converted_to_tenant: [],
  closed: [],
  lost_declined: [],
};

function validateEnquiryTransition(currentStatus: string, newStatus: string): void {
  const allowed = ENQUIRY_TRANSITIONS[currentStatus];
  if (!allowed || !allowed.includes(newStatus)) {
    throw new ConflictError(`Cannot transition enquiry from '${currentStatus}' to '${newStatus}'`);
  }
}

// Site visit transitions are validated in the shared lifecycle module
// (modules/site-visits/site-visit.service.ts) so seeker and landlord paths
// cannot diverge.

async function assertSiteVisitAccess(req: AuthenticatedRequest, visitId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessSiteVisit(userId, visitId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

// ============================================================================
// LISTING CONTROLLERS
// ============================================================================

export async function createListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);

  const listing = await repo.createListing({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    title: data.title,
    description: data.description,
    rentAmount: data.rentAmount,
    depositAmount: data.depositAmount,
    availableFrom: data.availableFrom ? new Date(data.availableFrom) : null,
    availableTo: data.availableTo ? new Date(data.availableTo) : null,
    furnished: data.furnished,
    petPolicy: data.petPolicy,
    smokingAllowed: data.smokingAllowed,
    features: data.features,
    amenities: data.amenities,
    images: data.images,
    floorPlanUrl: data.floorPlanUrl,
    virtualTourUrl: data.virtualTourUrl,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(normalizeListing(listing));
}

export async function getListing(req: AuthenticatedRequest, res: Response) {
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);
  res.json(normalizeListing(listing));
}

export async function updateListing(req: AuthenticatedRequest, res: Response) {
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateListing(getParam(req, 'listingId'), {
    title: data.title,
    description: data.description,
    rentAmount: data.rentAmount,
    depositAmount: data.depositAmount,
    availableFrom: data.availableFrom ? new Date(data.availableFrom) : null,
    availableTo: data.availableTo ? new Date(data.availableTo) : null,
    furnished: data.furnished,
    petPolicy: data.petPolicy,
    smokingAllowed: data.smokingAllowed,
    features: data.features,
    amenities: data.amenities,
    images: data.images,
    floorPlanUrl: data.floorPlanUrl,
    virtualTourUrl: data.virtualTourUrl,
  }, userId);
  if (!updated) throw new NotFoundError('Listing');
  await authz.invalidateUserPermissionCache(userId);
  res.json(normalizeListing(updated));
}

export async function deleteListing(req: AuthenticatedRequest, res: Response) {
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);
  const userId = assertAuth(req);
  await repo.deleteListing(getParam(req, 'listingId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listListings(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const listings = await repo.findListings({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    status: query.status as string | undefined,
    propertyType: query.propertyType as string | undefined,
    city: query.city as string | undefined,
    county: query.county as string | undefined,
    rentMin: query.rentMin !== undefined ? Number(query.rentMin) : undefined,
    rentMax: query.rentMax !== undefined ? Number(query.rentMax) : undefined,
    bedrooms: query.bedrooms !== undefined ? Number(query.bedrooms) : undefined,
    furnished: query.furnished !== undefined ? query.furnished === 'true' : undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(listings.map(normalizeListing));
}

export async function publishListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);

  const updated = await repo.setListingStatus(
    getParam(req, 'listingId'),
    'published',
    userId,
    'published_at',
  );
  if (!updated) throw new NotFoundError('Listing');
  await authz.invalidateUserPermissionCache(userId);
  await enqueueSearchAlert(getParam(req, 'listingId'));
  res.json(normalizeListing(updated));
}

export async function pauseListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);

  const updated = await repo.setListingStatus(
    getParam(req, 'listingId'),
    'paused',
    userId,
    'paused_at',
  );
  if (!updated) throw new NotFoundError('Listing');
  await authz.invalidateUserPermissionCache(userId);
  res.json(normalizeListing(updated));
}

export async function resumeListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);

  const updated = await repo.setListingStatus(
    getParam(req, 'listingId'),
    'published',
    userId,
    null,
  );
  if (!updated) throw new NotFoundError('Listing');
  await authz.invalidateUserPermissionCache(userId);
  await enqueueSearchAlert(getParam(req, 'listingId'));
  res.json(normalizeListing(updated));
}

export async function withdrawListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);

  const updated = await repo.setListingStatus(
    getParam(req, 'listingId'),
    'withdrawn',
    userId,
    'withdrawn_at',
  );
  if (!updated) throw new NotFoundError('Listing');
  await authz.invalidateUserPermissionCache(userId);
  res.json(normalizeListing(updated));
}

export async function archiveListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const listing = await repo.findListingById(getParam(req, 'listingId'));
  if (!listing) throw new NotFoundError('Listing');
  await assertPropertyAccess(req, listing.propertyId);

  const updated = await repo.setListingStatus(
    getParam(req, 'listingId'),
    'archived',
    userId,
    'archived_at',
  );
  if (!updated) throw new NotFoundError('Listing');
  await authz.invalidateUserPermissionCache(userId);
  res.json(normalizeListing(updated));
}

// ============================================================================
// SITE VISIT MANAGEMENT CONTROLLERS
//
// All transitions delegate to the site visit lifecycle module, which validates
// the transition server-side, revalidates availability, writes the history
// row and emits transactional outbox events.
// ============================================================================

function serializeVisit(visit: Record<string, unknown>): Record<string, unknown> {
  const iso = (value: unknown) =>
    value instanceof Date ? value.toISOString() : value;
  return {
    ...visit,
    scheduledAt: iso(visit.scheduledAt),
    createdAt: iso(visit.createdAt),
    updatedAt: iso(visit.updatedAt),
  };
}

export async function confirmSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);

  const data = req.body as { hostNotes?: string | null };
  const updated = await lifecycle.confirmVisit({
    visitId,
    userId,
    hostNotes: data.hostNotes,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.json(serializeVisit(updated as unknown as Record<string, unknown>));
}

export async function declineSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);

  const data = req.body as { reason?: string | null };
  const updated = await lifecycle.declineVisit({
    visitId,
    userId,
    reason: data.reason ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.json(serializeVisit(updated as unknown as Record<string, unknown>));
}

export async function rescheduleSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);

  const data = req.body as {
    scheduledAt: string;
    durationMinutes?: number;
    reason?: string | null;
  };
  if (!data.scheduledAt) {
    throw new ConflictError('scheduledAt is required when rescheduling a visit');
  }
  const updated = await lifecycle.rescheduleVisit({
    visitId,
    userId,
    scheduledAt: data.scheduledAt,
    durationMinutes: data.durationMinutes,
    reason: data.reason ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.json(serializeVisit(updated as unknown as Record<string, unknown>));
}

export async function cancelSiteVisitByLandlord(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);

  const data = req.body as { reason?: string | null };
  const updated = await lifecycle.cancelVisit({
    visitId,
    userId,
    reason: data.reason ?? null,
    cancelledBy: 'landlord',
  });
  await authz.invalidateUserPermissionCache(userId);
  res.json(serializeVisit(updated as unknown as Record<string, unknown>));
}

export async function completeSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);

  const data = req.body as { outcome?: string | null; hostNotes?: string | null };
  const updated = await lifecycle.completeVisit({
    visitId,
    userId,
    outcome: data.outcome ?? null,
    hostNotes: data.hostNotes,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.json(serializeVisit(updated as unknown as Record<string, unknown>));
}

export async function markSiteVisitNoShow(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  const visit = await repo.findSiteVisitById(visitId);
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);

  const data = req.body as { reason?: string | null };
  const updated = await lifecycle.markNoShow({
    visitId,
    userId,
    reason: data.reason ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.json(serializeVisit(updated as unknown as Record<string, unknown>));
}

// ============================================================================
// Landlord site visit listing / detail
// ============================================================================

export async function listLandlordSiteVisits(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as {
    status?: string;
    propertyId?: string;
    limit?: number;
    offset?: number;
  };
  const limit = query.limit ?? 20;
  const offset = query.offset ?? 0;
  const visits = await repo.findSiteVisitsByLandlord(userId, {
    status: query.status,
    propertyId: query.propertyId,
    limit,
    offset,
  });
  res.json({
    items: visits.map(serializeVisit),
    total: visits.length,
    limit,
    offset,
  });
}

// ============================================================================
// Availability management (landlord)
// ============================================================================

export async function listSiteVisitAvailability(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const propertyId = getParam(req, 'propertyId');
  const property = await repo.findPropertyById(propertyId);
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, propertyId);

  const [rules, exceptions] = await Promise.all([
    repo.listAvailabilityRules(propertyId),
    repo.listAvailabilityExceptions(propertyId),
  ]);
  void userId;
  res.json({ propertyId, rules, exceptions });
}

export async function upsertSiteVisitAvailabilityRule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const propertyId = getParam(req, 'propertyId');
  const property = await repo.findPropertyById(propertyId);
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, propertyId);

  const data = req.body as {
    dayOfWeek: string;
    startTime: string;
    endTime: string;
    slotDurationMinutes?: number;
    bufferMinutes?: number;
    maxBookingsPerSlot?: number;
    isActive?: boolean;
  };

  const rule = await repo.upsertAvailabilityRule(propertyId, {
    dayOfWeek: data.dayOfWeek,
    startTime: data.startTime,
    endTime: data.endTime,
    slotDurationMinutes: data.slotDurationMinutes ?? 30,
    bufferMinutes: data.bufferMinutes ?? 0,
    maxBookingsPerSlot: data.maxBookingsPerSlot ?? 1,
    isActive: data.isActive ?? true,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(rule);
}

export async function deleteSiteVisitAvailabilityRule(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const propertyId = getParam(req, 'propertyId');
  const ruleId = getParam(req, 'ruleId');
  const property = await repo.findPropertyById(propertyId);
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, propertyId);

  const deleted = await repo.deleteAvailabilityRule(propertyId, ruleId);
  if (!deleted) throw new NotFoundError('Availability rule');
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function upsertSiteVisitAvailabilityException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const propertyId = getParam(req, 'propertyId');
  const property = await repo.findPropertyById(propertyId);
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, propertyId);

  const data = req.body as {
    exceptionDate: string;
    reason?: string | null;
    isUnavailable?: boolean;
    startTime?: string | null;
    endTime?: string | null;
  };

  const exception = await repo.upsertAvailabilityException(propertyId, {
    exceptionDate: data.exceptionDate,
    reason: data.reason ?? null,
    isUnavailable: data.isUnavailable ?? true,
    startTime: data.startTime ?? null,
    endTime: data.endTime ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(exception);
}

export async function deleteSiteVisitAvailabilityException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const propertyId = getParam(req, 'propertyId');
  const exceptionId = getParam(req, 'exceptionId');
  const property = await repo.findPropertyById(propertyId);
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, propertyId);

  const deleted = await repo.deleteAvailabilityException(propertyId, exceptionId);
  if (!deleted) throw new NotFoundError('Availability exception');
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function getLandlordSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visit = await repo.findSiteVisitById(getParam(req, 'visitId'));
  if (!visit) throw new NotFoundError('Site visit');
  await assertPropertyAccess(req, visit.propertyId);
  res.json(serializeVisit(visit as unknown as Record<string, unknown>));
}

// ============================================================================
// TENANT CONTROLLERS
// ============================================================================

export async function createTenant(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);
  if (data.tenancyId) {
    await assertTenancyAccess(req, data.tenancyId);
    const tenancy = await repo.findTenancyById(data.tenancyId);
    if (!tenancy) throw new NotFoundError('Tenancy not found');
    if (tenancy.status !== 'active') {
      throw new ConflictError(
        `Cannot link tenant to tenancy with status '${tenancy.status}': tenancy must be active`,
      );
    }
    // Cross-unit check: tenancy must belong to the same unit as the tenant.
    if (data.unitId && tenancy.unitId !== data.unitId) {
      throw new ConflictError(
        `Cannot link tenant to tenancy: tenancy unit (${tenancy.unitId}) does not match tenant unit (${data.unitId})`,
      );
    }
    // Cross-property check: tenancy must belong to the same property as the tenant.
    if (tenancy.propertyId !== data.propertyId) {
      throw new ConflictError(
        `Cannot link tenant to tenancy: tenancy property (${tenancy.propertyId}) does not match tenant property (${data.propertyId})`,
      );
    }
  }

  // Prevent creating an active tenant on a unit that already has an active
  // tenant, which would bypass unit availability and conflict checks.
  // The check and insert run inside a transaction with a FOR UPDATE lock on
  // the unit row so concurrent requests cannot both pass the check. The
  // partial unique index on tenants(unit_id) WHERE status = 'active' provides
  // a database-level backstop.
  if (data.status === 'active' && data.unitId) {
    await transaction(async (client) => {
      await client.query(`SELECT id FROM units WHERE id = $1 FOR UPDATE`, [data.unitId]);
      const existing = await repo.findActiveTenantOnUnitWithClient(client, data.unitId);
      if (existing) {
        throw new ConflictError('This unit already has an active tenant');
      }
    });
  }

  const tenant = await repo.createTenant({
    userId: data.userId ?? null,
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    tenancyId: data.tenancyId ?? null,
    fullName: data.fullName,
    email: data.email,
    phone: data.phone,
    idNumber: data.idNumber,
    idType: data.idType,
    emergencyContactName: data.emergencyContactName,
    emergencyContactPhone: data.emergencyContactPhone,
    employerName: data.employerName,
    employerContact: data.employerContact,
    monthlyIncome: data.monthlyIncome,
    previousLandlordName: data.previousLandlordName,
    previousLandlordContact: data.previousLandlordContact,
    moveInDate: data.moveInDate ? new Date(data.moveInDate) : null,
    moveOutDate: data.moveOutDate ? new Date(data.moveOutDate) : null,
    status: data.status,
    notes: data.notes,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(tenant);
}

// Wrapper: converts database unique violations (from the partial unique index
// on active tenants per unit) into proper ConflictError responses. This handles
// the race condition where two concurrent requests both pass the pre-insert
// check but only one can insert due to the database-level unique constraint.
export async function createTenantSafe(req: AuthenticatedRequest, res: Response) {
  try {
    await createTenant(req, res);
  } catch (error: any) {
    if (error.code === '23505') {
      throw new ConflictError('This unit already has an active tenant');
    }
    throw error;
  }
}

export async function getTenant(req: AuthenticatedRequest, res: Response) {
  const tenant = await repo.findTenantById(getParam(req, 'tenantId'));
  if (!tenant) throw new NotFoundError('Tenant');
  await assertPropertyAccess(req, tenant.propertyId);
  res.json(tenant);
}

export async function updateTenant(req: AuthenticatedRequest, res: Response) {
  const tenant = await repo.findTenantById(getParam(req, 'tenantId'));
  if (!tenant) throw new NotFoundError('Tenant');
  await assertPropertyAccess(req, tenant.propertyId);
  const userId = assertAuth(req);
  const data = req.body;

  const targetUnitId = data.unitId !== undefined ? data.unitId : tenant.unitId;
  const targetTenancyId =
    data.tenancyId !== undefined ? data.tenancyId : tenant.tenancyId;

  // If activating the tenant, validate unit availability and tenancy status.
  if (data.status === 'active' && targetUnitId) {
    await transaction(async (client) => {
      await client.query(`SELECT id FROM units WHERE id = $1 FOR UPDATE`, [targetUnitId]);
      const existing = await repo.findActiveTenantOnUnitWithClient(client, targetUnitId);
      if (existing && existing.id !== tenant.id) {
        throw new ConflictError('This unit already has an active tenant');
      }
    });
  }

  // A tenant can only be linked to an active tenancy that belongs to the same
  // unit and property as the tenant record. This prevents cross-unit and
  // cross-property tenancy association through PATCH.
  if (data.tenancyId !== undefined && targetTenancyId) {
    const tenancy = await repo.findTenancyById(targetTenancyId);
    if (!tenancy) throw new NotFoundError('Tenancy not found');
    if (tenancy.status !== 'active') {
      throw new ConflictError(
        `Cannot link tenant to tenancy with status '${tenancy.status}': tenancy must be active`,
      );
    }
    // Cross-unit check on update: tenancy must belong to the target unit.
    if (targetUnitId && tenancy.unitId !== targetUnitId) {
      throw new ConflictError(
        `Cannot link tenant to tenancy: tenancy unit (${tenancy.unitId}) does not match target unit (${targetUnitId})`,
      );
    }
    // Cross-property check on update: tenancy must belong to the same property.
    if (tenancy.propertyId !== tenant.propertyId) {
      throw new ConflictError(
        `Cannot link tenant to tenancy: tenancy property (${tenancy.propertyId}) does not match tenant property (${tenant.propertyId})`,
      );
    }
  }

  // If changing the unit while keeping an existing tenancy, verify the
  // tenancy belongs to the new unit.
  if (data.unitId !== undefined && data.tenancyId === undefined && tenant.tenancyId && targetUnitId) {
    const tenancy = await repo.findTenancyById(tenant.tenancyId);
    if (tenancy && tenancy.unitId !== targetUnitId) {
      throw new ConflictError(
        `Cannot move tenant to unit ${targetUnitId}: existing tenancy belongs to unit ${tenancy.unitId}`,
      );
    }
  }

  const updated = await repo.updateTenant(getParam(req, 'tenantId'), {
    unitId: data.unitId,
    tenancyId: data.tenancyId,
    fullName: data.fullName,
    email: data.email,
    phone: data.phone,
    idNumber: data.idNumber,
    idType: data.idType,
    emergencyContactName: data.emergencyContactName,
    emergencyContactPhone: data.emergencyContactPhone,
    employerName: data.employerName,
    employerContact: data.employerContact,
    monthlyIncome: data.monthlyIncome,
    previousLandlordName: data.previousLandlordName,
    previousLandlordContact: data.previousLandlordContact,
    moveInDate: data.moveInDate ? new Date(data.moveInDate) : null,
    moveOutDate: data.moveOutDate ? new Date(data.moveOutDate) : null,
    status: data.status,
    notes: data.notes,
  }, userId);
  if (!updated) throw new NotFoundError('Tenant');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function deleteTenant(req: AuthenticatedRequest, res: Response) {
  const tenant = await repo.findTenantById(getParam(req, 'tenantId'));
  if (!tenant) throw new NotFoundError('Tenant');
  await assertPropertyAccess(req, tenant.propertyId);
  const userId = assertAuth(req);
  await repo.deleteTenant(getParam(req, 'tenantId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listTenants(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const tenants = await repo.findTenants({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    tenancyId: query.tenancyId as string | undefined,
    status: query.status as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(tenants);
}

// ============================================================================
// GARBAGE PROVIDER CONTROLLERS
// ============================================================================

export async function createGarbageProvider(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  const provider = await repo.createGarbageProvider({
    organisationId: data.organisationId ?? null,
    name: data.name,
    contactPerson: data.contactPerson,
    contactPhone: data.contactPhone,
    contactEmail: data.contactEmail,
    address: data.address,
    serviceAreas: data.serviceAreas,
    status: data.status,
    rating: data.rating,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(provider);
}

export async function getGarbageProvider(req: AuthenticatedRequest, res: Response) {
  const provider = await repo.findGarbageProviderById(getParam(req, 'providerId'));
  if (!provider) throw new NotFoundError('Garbage provider');
  res.json(provider);
}

export async function updateGarbageProvider(req: AuthenticatedRequest, res: Response) {
  const provider = await repo.findGarbageProviderById(getParam(req, 'providerId'));
  if (!provider) throw new NotFoundError('Garbage provider');
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateGarbageProvider(getParam(req, 'providerId'), {
    name: data.name,
    contactPerson: data.contactPerson,
    contactPhone: data.contactPhone,
    contactEmail: data.contactEmail,
    address: data.address,
    serviceAreas: data.serviceAreas,
    status: data.status,
    rating: data.rating,
  }, userId);
  if (!updated) throw new NotFoundError('Garbage provider');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function deleteGarbageProvider(req: AuthenticatedRequest, res: Response) {
  const provider = await repo.findGarbageProviderById(getParam(req, 'providerId'));
  if (!provider) throw new NotFoundError('Garbage provider');
  const userId = assertAuth(req);
  await repo.deleteGarbageProvider(getParam(req, 'providerId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listGarbageProviders(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const providers = await repo.findGarbageProviders({
    status: query.status as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(providers);
}

// ============================================================================
// GARBAGE ASSIGNMENT CONTROLLERS
// ============================================================================

export async function createGarbageAssignment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);

  const assignment = await repo.createGarbageAssignment({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    garbageProviderId: data.garbageProviderId,
    assignmentType: data.assignmentType,
    frequency: data.frequency,
    dayOfWeek: data.dayOfWeek,
    timeSlot: data.timeSlot,
    status: 'active',
    assignedBy: userId,
    effectiveFrom: new Date(data.effectiveFrom),
    effectiveTo: data.effectiveTo ? new Date(data.effectiveTo) : null,
    notes: data.notes,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(assignment);
}

export async function getGarbageAssignment(req: AuthenticatedRequest, res: Response) {
  const assignment = await repo.findGarbageAssignmentById(getParam(req, 'assignmentId'));
  if (!assignment) throw new NotFoundError('Garbage assignment');
  await assertPropertyAccess(req, assignment.propertyId);
  res.json(assignment);
}

export async function updateGarbageAssignment(req: AuthenticatedRequest, res: Response) {
  const assignment = await repo.findGarbageAssignmentById(getParam(req, 'assignmentId'));
  if (!assignment) throw new NotFoundError('Garbage assignment');
  await assertPropertyAccess(req, assignment.propertyId);
  const data = req.body;
  const updated = await repo.updateGarbageAssignment(getParam(req, 'assignmentId'), {
    unitId: data.unitId,
    garbageProviderId: data.garbageProviderId,
    assignmentType: data.assignmentType,
    frequency: data.frequency,
    dayOfWeek: data.dayOfWeek,
    timeSlot: data.timeSlot,
    status: data.status,
    effectiveFrom: data.effectiveFrom ? new Date(data.effectiveFrom) : undefined,
    effectiveTo: data.effectiveTo ? new Date(data.effectiveTo) : null,
    notes: data.notes,
  });
  if (!updated) throw new NotFoundError('Garbage assignment');
  res.json(updated);
}

export async function deleteGarbageAssignment(req: AuthenticatedRequest, res: Response) {
  const assignment = await repo.findGarbageAssignmentById(getParam(req, 'assignmentId'));
  if (!assignment) throw new NotFoundError('Garbage assignment');
  await assertPropertyAccess(req, assignment.propertyId);
  const userId = assertAuth(req);
  await repo.deleteGarbageAssignment(getParam(req, 'assignmentId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listGarbageAssignments(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const assignments = await repo.findGarbageAssignments({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    garbageProviderId: query.garbageProviderId as string | undefined,
    status: query.status as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(assignments);
}

// ============================================================================
// GARBAGE COLLECTION REQUEST CONTROLLERS
// ============================================================================

export async function createGarbageCollectionRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);

  const request = await repo.createGarbageCollectionRequest({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    garbageProviderId: data.garbageProviderId ?? null,
    requestType: data.requestType,
    status: 'pending',
    scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : null,
    notes: data.notes,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(request);
}

export async function getGarbageCollectionRequest(req: AuthenticatedRequest, res: Response) {
  const request = await repo.findGarbageCollectionRequestById(getParam(req, 'requestId'));
  if (!request) throw new NotFoundError('Garbage collection request');
  await assertPropertyAccess(req, request.propertyId);
  res.json(request);
}

export async function updateGarbageCollectionRequest(req: AuthenticatedRequest, res: Response) {
  const request = await repo.findGarbageCollectionRequestById(getParam(req, 'requestId'));
  if (!request) throw new NotFoundError('Garbage collection request');
  await assertPropertyAccess(req, request.propertyId);
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateGarbageCollectionRequest(getParam(req, 'requestId'), {
    garbageProviderId: data.garbageProviderId,
    requestType: data.requestType,
    status: data.status,
    scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : null,
    completedAt: data.completedAt ? new Date(data.completedAt) : null,
    notes: data.notes,
  }, userId);
  if (!updated) throw new NotFoundError('Garbage collection request');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function deleteGarbageCollectionRequest(req: AuthenticatedRequest, res: Response) {
  const request = await repo.findGarbageCollectionRequestById(getParam(req, 'requestId'));
  if (!request) throw new NotFoundError('Garbage collection request');
  await assertPropertyAccess(req, request.propertyId);
  const userId = assertAuth(req);
  await repo.deleteGarbageCollectionRequest(getParam(req, 'requestId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listGarbageCollectionRequests(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const requests = await repo.findGarbageCollectionRequests({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    garbageProviderId: query.garbageProviderId as string | undefined,
    status: query.status as string | undefined,
    requestType: query.requestType as string | undefined,
    fromDate: query.fromDate ? new Date(query.fromDate as string) : undefined,
    toDate: query.toDate ? new Date(query.toDate as string) : undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(requests);
}

// ============================================================================
// DASHBOARD CONTROLLER
// ============================================================================

export async function getDashboardStats(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query;
  const propertyId = query.propertyId as string | undefined;

  if (propertyId) {
    await assertPropertyAccess(req, propertyId);
  }

  const stats = await repo.getDashboardStats(propertyId);
  res.json(stats);
}

// ============================================================================
// PROPERTY CONTROLLERS
// ============================================================================

export async function createProperty(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  const property = await repo.createProperty({
    title: data.title,
    description: data.description,
    propertyType: data.propertyType,
    address: data.address,
    city: data.city,
    county: data.county,
    country: data.country,
    latitude: data.latitude,
    longitude: data.longitude,
    totalUnits: data.totalUnits,
    amenities: data.amenities,
    features: data.features,
    images: data.images,
    status: data.status,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(property);
}

export async function getProperty(req: AuthenticatedRequest, res: Response) {
  const property = await repo.findPropertyById(getParam(req, 'propertyId'));
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, property.id);
  res.json(property);
}

export async function updateProperty(req: AuthenticatedRequest, res: Response) {
  const property = await repo.findPropertyById(getParam(req, 'propertyId'));
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, property.id);
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateProperty(getParam(req, 'propertyId'), {
    title: data.title,
    description: data.description,
    propertyType: data.propertyType,
    address: data.address,
    city: data.city,
    county: data.county,
    country: data.country,
    latitude: data.latitude,
    longitude: data.longitude,
    totalUnits: data.totalUnits,
    amenities: data.amenities,
    features: data.features,
    images: data.images,
    status: data.status,
  }, userId);
  if (!updated) throw new NotFoundError('Property');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function deleteProperty(req: AuthenticatedRequest, res: Response) {
  const property = await repo.findPropertyById(getParam(req, 'propertyId'));
  if (!property) throw new NotFoundError('Property');
  await assertPropertyAccess(req, property.id);
  const userId = assertAuth(req);
  await repo.deleteProperty(getParam(req, 'propertyId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listProperties(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const properties = await repo.findProperties({
    status: query.status as string | undefined,
    propertyType: query.propertyType as string | undefined,
    city: query.city as string | undefined,
    county: query.county as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(properties);
}

// ============================================================================
// UNIT CONTROLLERS
// ============================================================================

export async function createUnit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);

  const unit = await repo.createUnit({
    propertyId: data.propertyId,
    unitNumber: data.unitNumber,
    building: data.building,
    floor: data.floor,
    unitType: data.unitType,
    bedrooms: data.bedrooms,
    bathrooms: data.bathrooms,
    areaSqm: data.areaSqm,
    rentAmount: data.rentAmount,
    depositAmount: data.depositAmount,
    amenities: data.amenities,
    description: data.description,
    status: data.status,
    hasSeparateMeter: data.hasSeparateMeter,
    meterNumber: data.meterNumber,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(unit);
}

export async function getUnit(req: AuthenticatedRequest, res: Response) {
  const unit = await repo.findUnitById(getParam(req, 'unitId'));
  if (!unit) throw new NotFoundError('Unit');
  await assertPropertyAccess(req, unit.propertyId);
  res.json(unit);
}

export async function updateUnit(req: AuthenticatedRequest, res: Response) {
  const unit = await repo.findUnitById(getParam(req, 'unitId'));
  if (!unit) throw new NotFoundError('Unit');
  await assertPropertyAccess(req, unit.propertyId);
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateUnit(getParam(req, 'unitId'), {
    unitNumber: data.unitNumber,
    building: data.building,
    floor: data.floor,
    unitType: data.unitType,
    bedrooms: data.bedrooms,
    bathrooms: data.bathrooms,
    areaSqm: data.areaSqm,
    rentAmount: data.rentAmount,
    depositAmount: data.depositAmount,
    amenities: data.amenities,
    description: data.description,
    status: data.status,
    hasSeparateMeter: data.hasSeparateMeter,
    meterNumber: data.meterNumber,
  }, userId);
  if (!updated) throw new NotFoundError('Unit');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function deleteUnit(req: AuthenticatedRequest, res: Response) {
  const unit = await repo.findUnitById(getParam(req, 'unitId'));
  if (!unit) throw new NotFoundError('Unit');
  await assertPropertyAccess(req, unit.propertyId);
  const userId = assertAuth(req);
  await repo.deleteUnit(getParam(req, 'unitId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listUnits(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const units = await repo.findUnits({
    propertyId: query.propertyId as string | undefined,
    status: query.status as string | undefined,
    unitType: query.unitType as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(units);
}

// ============================================================================
// PROPERTY DOCUMENT CONTROLLERS
// ============================================================================

export async function createPropertyDocument(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);

  const document = await repo.createPropertyDocument({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    category: data.category,
    title: data.title,
    description: data.description,
    fileName: data.fileName,
    filePath: data.filePath,
    fileSizeBytes: data.fileSizeBytes,
    mimeType: data.mimeType,
    visibility: data.visibility,
    uploadedBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(document);
}

export async function listPropertyDocuments(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const propertyId = query.propertyId as string | undefined;
  if (propertyId) await assertPropertyAccess(req, propertyId);

  const documents = await repo.findPropertyDocuments({
    propertyId,
    unitId: query.unitId as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(documents);
}

// ============================================================================
// ENQUIRY CONTROLLERS
// ============================================================================

export async function createEnquiry(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);

  const enquiry = await repo.createEnquiry({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    listingId: data.listingId ?? null,
    prospectiveRenterId: userId,
    prospectiveRenterName: data.prospectiveRenterName,
    prospectiveRenterEmail: data.prospectiveRenterEmail,
    prospectiveRenterPhone: data.prospectiveRenterPhone,
    enquirySource: data.enquirySource,
    message: data.message,
    assignedToUserId: data.assignedToUserId ?? null,
    followUpDate: data.followUpDate ? new Date(data.followUpDate) : null,
    internalNotes: data.internalNotes,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(enquiry);
}

export async function getEnquiry(req: AuthenticatedRequest, res: Response) {
  const enquiry = await repo.findEnquiryById(getParam(req, 'enquiryId'));
  if (!enquiry) throw new NotFoundError('Enquiry');
  await assertPropertyAccess(req, enquiry.propertyId);
  res.json(enquiry);
}

export async function updateEnquiry(req: AuthenticatedRequest, res: Response) {
  const enquiry = await repo.findEnquiryById(getParam(req, 'enquiryId'));
  if (!enquiry) throw new NotFoundError('Enquiry');
  await assertPropertyAccess(req, enquiry.propertyId);
  const userId = assertAuth(req);
  const data = req.body;

  if (data.status && data.status !== enquiry.status) {
    validateEnquiryTransition(enquiry.status, data.status);
  }

  const updated = await repo.updateEnquiry(getParam(req, 'enquiryId'), {
    unitId: data.unitId,
    listingId: data.listingId,
    prospectiveRenterName: data.prospectiveRenterName,
    prospectiveRenterEmail: data.prospectiveRenterEmail,
    prospectiveRenterPhone: data.prospectiveRenterPhone,
    enquirySource: data.enquirySource,
    message: data.message,
    status: data.status,
    assignedToUserId: data.assignedToUserId,
    followUpDate: data.followUpDate ? new Date(data.followUpDate) : null,
    internalNotes: data.internalNotes,
  }, userId);
  if (!updated) throw new NotFoundError('Enquiry');

  if (data.status && data.status !== enquiry.status) {
    const notifications = new NotificationService();
    await notifications.createOutboxEvent({
      idempotencyKey: `enquiry.status.${getParam(req, 'enquiryId')}:${data.status}:${userId}`,
      eventType: 'enquiry.status_changed',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: enquiry.prospectiveRenterId ? [enquiry.prospectiveRenterId] : [],
      organisationId: null,
      resourceType: 'enquiry',
      resourceId: getParam(req, 'enquiryId'),
      payload: { enquiryId: getParam(req, 'enquiryId'), status: data.status, propertyId: enquiry.propertyId },
      channels: ['in_app', 'email'],
    });
  }

  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function listEnquiries(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const enquiries = await repo.findEnquiries({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    listingId: query.listingId as string | undefined,
    status: query.status as string | undefined,
    source: query.source as string | undefined,
    assignedToUserId: query.assignedToUserId as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(enquiries);
}

export async function addEnquiryNote(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  const enquiry = await repo.findEnquiryById(getParam(req, 'enquiryId'));
  if (!enquiry) throw new NotFoundError('Enquiry');
  await assertPropertyAccess(req, enquiry.propertyId);

  await repo.createEnquiryNote({
    enquiryId: getParam(req, 'enquiryId'),
    userId,
    note: data.note,
    isInternal: data.isInternal,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json({ success: true });
}

export async function getEnquiryNotes(req: AuthenticatedRequest, res: Response) {
  const enquiry = await repo.findEnquiryById(getParam(req, 'enquiryId'));
  if (!enquiry) throw new NotFoundError('Enquiry');
  await assertPropertyAccess(req, enquiry.propertyId);

  const notes = await repo.findEnquiryNotes(getParam(req, 'enquiryId'));
  res.json(notes);
}

// ============================================================================
// CONVERSATION CONTROLLERS
// ============================================================================

export async function createConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body as {
    type?: string;
    subject?: string;
    propertyId?: string;
    unitId?: string;
    enquiryId?: string;
    siteVisitId?: string;
    tenancyId?: string;
    participantUserIds?: string[];
    message?: string;
  };

  const result = await messagingService.startConversation(userId, {
    type: (data.type ?? 'general') as ConversationContextType,
    subject: data.subject ?? null,
    propertyId: data.propertyId ?? null,
    unitId: data.unitId ?? null,
    enquiryId: data.enquiryId ?? null,
    siteVisitId: data.siteVisitId ?? null,
    tenancyId: data.tenancyId ?? null,
    participantUserIds: data.participantUserIds ?? [],
    message: data.message ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(result.reused ? 200 : 201).json(result.conversation);
}

export async function getConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await messagingService.getMyConversation(userId, getParam(req, 'conversationId')));
}

export async function listConversations(req: AuthenticatedRequest, res: Response) {
  const query = req.query as Record<string, unknown>;
  const userId = assertAuth(req);
  const result = await messagingService.listMyConversations(userId, {
    type: typeof query.type === 'string' ? query.type : undefined,
    propertyId: typeof query.propertyId === 'string' ? query.propertyId : undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(result.items);
}

export async function getConversationParticipants(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const conversationId = getParam(req, 'conversationId');
  const result = await messagingService.getMyConversation(userId, conversationId);
  res.json(result.participants);
}

// ============================================================================
// MESSAGE CONTROLLERS
// ============================================================================

export async function sendMessage(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body as { conversationId: string; content: string; type?: string; replyToId?: string };
  const message = await messagingService.sendMessage(userId, {
    conversationId: data.conversationId,
    content: data.content,
    type: data.type,
    replyToId: data.replyToId ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(message);
}

export async function listMessages(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as Record<string, unknown>;
  const result = await messagingService.listMyMessages(userId, getParam(req, 'conversationId'), {
    limit: 50,
    before: typeof query.before === 'string' ? messagingRepo.decodeMessageCursor(query.before) : null,
  });
  res.json(result.items);
}

export async function markMessageRead(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const messageId = getParam(req, 'messageId');
  await messagingService.markMessageRead(userId, messageId);
  res.status(204).send();
}

// ============================================================================
// RENTAL PROPOSAL CONTROLLERS
// ============================================================================

export async function createRentalProposal(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId, 'property.update');
  if (data.unitId) await assertUnitAccess(req, data.unitId);

  const proposal = await repo.createRentalProposal({
    enquiryId: data.enquiryId ?? null,
    rentalApplicationId: data.rentalApplicationId ?? null,
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    prospectiveRenterId: data.prospectiveRenterId,
    landlordUserId: userId,
    type: data.type,
    proposedRentAmount: data.proposedRentAmount,
    proposedDepositAmount: data.proposedDepositAmount,
    proposedStartDate: new Date(data.proposedStartDate),
    proposedEndDate: data.proposedEndDate ? new Date(data.proposedEndDate) : null,
    proposedRentDueDay: data.proposedRentDueDay,
    specialConditions: data.specialConditions,
    notes: data.notes,
    expiresAt: new Date(data.expiresAt),
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(proposal);
}

export async function getRentalProposal(req: AuthenticatedRequest, res: Response) {
  const proposal = await repo.findRentalProposalById(getParam(req, 'proposalId'));
  if (!proposal) throw new NotFoundError('Rental proposal');
  await assertPropertyAccess(req, proposal.propertyId, 'property.update');
  res.json(proposal);
}

export async function updateRentalProposal(req: AuthenticatedRequest, res: Response) {
  const proposal = await repo.findRentalProposalById(getParam(req, 'proposalId'));
  if (!proposal) throw new NotFoundError('Rental proposal');
  await assertPropertyAccess(req, proposal.propertyId, 'property.update');
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateRentalProposal(getParam(req, 'proposalId'), {
    proposedRentAmount: data.proposedRentAmount,
    proposedDepositAmount: data.proposedDepositAmount,
    proposedStartDate: data.proposedStartDate ? new Date(data.proposedStartDate) : undefined,
    proposedEndDate: data.proposedEndDate ? new Date(data.proposedEndDate) : null,
    proposedRentDueDay: data.proposedRentDueDay,
    specialConditions: data.specialConditions,
    notes: data.notes,
    expiresAt: data.expiresAt ? new Date(data.expiresAt) : undefined,
  }, userId);
  if (!updated) throw new NotFoundError('Rental proposal');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function listRentalProposals(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const proposals = await repo.findRentalProposals({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    prospectiveRenterId: query.prospectiveRenterId as string | undefined,
    status: query.status as string | undefined,
    type: query.type as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(proposals);
}

export async function actionRentalProposal(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  const proposal = await repo.findRentalProposalById(getParam(req, 'proposalId'));
  if (!proposal) throw new NotFoundError('Rental proposal');
  await assertPropertyAccess(req, proposal.propertyId, 'property.update');

  let newStatus: string;
  let timestampField: 'accepted_at' | 'declined_at' | 'withdrawn_at' | 'confirmed_at' | null = null;
  let eventType: string;

  switch (data.action) {
    case 'send':
      newStatus = 'sent';
      eventType = 'proposal.sent';
      break;
    case 'request_changes':
      newStatus = 'changes_requested';
      eventType = 'proposal.changes_requested';
      break;
    case 'accept':
      newStatus = 'accepted';
      timestampField = 'accepted_at';
      eventType = 'proposal.accepted';
      break;
    case 'decline':
      newStatus = 'declined';
      timestampField = 'declined_at';
      eventType = 'proposal.declined';
      break;
    case 'withdraw':
      newStatus = 'withdrawn';
      timestampField = 'withdrawn_at';
      eventType = 'proposal.withdrawn';
      break;
    case 'confirm':
      newStatus = 'confirmed';
      timestampField = 'confirmed_at';
      eventType = 'proposal.confirmed';
      break;
    default:
      throw new ForbiddenError('Invalid action');
  }

  const updated = await repo.setRentalProposalStatus(
    getParam(req, 'proposalId'),
    newStatus,
    userId,
    data.reason ?? null,
    timestampField,
    // Critical event persisted atomically with the status change.
    { eventType, idempotencyKey: `${eventType}:${getParam(req, 'proposalId')}` },
  );
  if (!updated) throw new NotFoundError('Rental proposal');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

// ============================================================================
// FINANCIAL CONTROLLERS - INVOICES
// ============================================================================

export async function createInvoice(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);

  const invoice = await repo.createInvoice({
    invoiceNumber: data.invoiceNumber || `INV-${Date.now()}`,
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    tenantId: data.tenantId ?? null,
    tenancyId: data.tenancyId ?? null,
    billingPeriodStart: new Date(data.billingPeriodStart),
    billingPeriodEnd: new Date(data.billingPeriodEnd),
    dueDate: new Date(data.dueDate),
    subtotal: data.subtotal ?? data.totalAmount,
    taxAmount: data.taxAmount ?? 0,
    totalAmount: data.totalAmount,
    notes: data.notes ?? null,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(invoice);
}

export async function getInvoice(req: AuthenticatedRequest, res: Response) {
  const invoice = await repo.findInvoiceById(getParam(req, 'invoiceId'));
  if (!invoice) throw new NotFoundError('Invoice');
  await assertPropertyAccess(req, invoice.propertyId);
  res.json(invoice);
}

export async function listInvoices(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const invoices = await repo.findInvoices({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    tenantId: query.tenantId as string | undefined,
    tenancyId: query.tenancyId as string | undefined,
    status: query.status as string | undefined,
    fromDate: query.fromDate ? new Date(query.fromDate as string) : undefined,
    toDate: query.toDate ? new Date(query.toDate as string) : undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(invoices);
}

export async function recordPayment(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;

  let invoiceId: string | null = null;
  let propertyId: string;
  let tenantId: string | null = null;

  if (data.invoiceId) {
    const invoice = await repo.findInvoiceById(data.invoiceId);
    if (!invoice) throw new NotFoundError('Invoice');
    await assertPropertyAccess(req, invoice.propertyId);
    invoiceId = data.invoiceId;
    propertyId = invoice.propertyId;
    tenantId = invoice.tenantId;
  } else {
    throw new ForbiddenError('invoiceId is required for recording payments');
  }

  const transaction = await repo.createPaymentTransaction({
    transactionReference: data.transactionReference || `PAY-${Date.now()}`,
    invoiceId,
    tenantId,
    propertyId,
    amount: data.amount,
    currency: 'KES',
    provider: data.provider,
    providerTransactionId: data.providerTransactionId,
    status: data.status || 'completed',
    paymentDate: data.paymentDate ? new Date(data.paymentDate) : new Date(),
    callbackPayload: data.callbackPayload,
    idempotencyKey: data.idempotencyKey,
    createdBy: userId,
  });

  // If invoice specified and payment completed, update invoice
  if (invoiceId && data.status === 'completed') {
    const invoice = await repo.findInvoiceById(invoiceId);
    if (invoice) {
      const newPaid = Number(invoice.amountPaid) + data.amount;
      const newOutstanding = Math.max(0, Number(invoice.amountOutstanding) - data.amount);
      const newStatus = newOutstanding <= 0 ? 'paid' : 'partially_paid';
      await repo.updateInvoiceStatus(invoiceId, newStatus, newPaid, newOutstanding, userId);
    }
  }

  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(transaction);
}

export async function listRentLedger(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const propertyId = query.propertyId as string | undefined;
  if (propertyId) await assertPropertyAccess(req, propertyId);

  const entries = await repo.findRentLedgerEntries({
    tenancyId: query.tenancyId as string | undefined,
    tenantId: query.tenantId as string | undefined,
    propertyId,
    limit: query.limit ? Number(query.limit) : 50,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(entries);
}

// ============================================================================
// MAINTENANCE CONTROLLERS
// ============================================================================

export async function reportIssue(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertPropertyAccess(req, data.propertyId);
  if (data.unitId) await assertUnitAccess(req, data.unitId);
  if (data.tenancyId) await assertTenancyAccess(req, data.tenancyId);

  const issue = await repo.reportIssue({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    tenancyId: data.tenancyId ?? null,
    reporterId: userId,
    reporterRole: data.reporterRole,
    title: data.title,
    description: data.description,
    category: data.category,
    priority: data.priority,
    assignedToUserId: data.assignedToUserId ?? null,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(issue);
}

export async function getIssue(req: AuthenticatedRequest, res: Response) {
  const issue = await repo.findIssueById(getParam(req, 'issueId'));
  if (!issue) throw new NotFoundError('Issue');
  await assertPropertyAccess(req, issue.propertyId);
  res.json(issue);
}

export async function updateIssue(req: AuthenticatedRequest, res: Response) {
  const issue = await repo.findIssueById(getParam(req, 'issueId'));
  if (!issue) throw new NotFoundError('Issue');
  await assertPropertyAccess(req, issue.propertyId);
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateIssue(getParam(req, 'issueId'), {
    title: data.title,
    description: data.description,
    category: data.category,
    priority: data.priority,
    status: data.status,
    assignedToUserId: data.assignedToUserId,
    estimatedCost: data.estimatedCost,
    actualCost: data.actualCost,
    resolutionNotes: data.resolutionNotes,
  }, userId);
  if (!updated) throw new NotFoundError('Issue');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function listIssues(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const issues = await repo.findIssues({
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    tenancyId: query.tenancyId as string | undefined,
    category: query.category as string | undefined,
    priority: query.priority as string | undefined,
    status: query.status as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(issues);
}

// ============================================================================
// LEASE / RENTAL AGREEMENT CONTROLLERS
// ============================================================================

export async function createRentalAgreement(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  // Access and denormalized FKs are derived from the tenancy
  const tenancy = await repo.findTenancyById(data.tenancyId);
  if (!tenancy) throw new NotFoundError('Tenancy');
  await assertPropertyAccess(req, tenancy.propertyId);
  const tenant = await repo.findTenantByTenancyId(data.tenancyId);
  if (!tenant) throw new NotFoundError('Tenant for tenancy');
  const agreement = await repo.createRentalAgreement({
    tenancyId: data.tenancyId,
    tenantId: tenant.id,
    propertyId: tenancy.propertyId,
    unitId: tenancy.unitId,
    agreementNumber: data.agreementNumber,
    startDate: new Date(data.startDate),
    endDate: data.endDate ? new Date(data.endDate) : null,
    monthlyRent: data.monthlyRent,
    depositAmount: data.depositAmount,
    rentDueDay: data.rentDueDay,
    paymentMethod: data.paymentMethod,
    specialConditions: data.specialConditions,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(agreement);
}

export async function getRentalAgreement(req: AuthenticatedRequest, res: Response) {
  const agreement = await repo.findRentalAgreementById(getParam(req, 'agreementId'));
  if (!agreement) throw new NotFoundError('Rental agreement');
  // Verify access via the tenancy the agreement belongs to
  const tenancy = await repo.findTenancyById(agreement.tenancyId);
  if (tenancy) await assertPropertyAccess(req, tenancy.propertyId);
  res.json(agreement);
}

export async function listRentalAgreements(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const agreements = await repo.findRentalAgreements({
    tenancyId: query.tenancyId as string | undefined,
    propertyId: query.propertyId as string | undefined,
    status: query.status as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(agreements);
}

export async function updateRentalAgreement(req: AuthenticatedRequest, res: Response) {
  const agreement = await repo.findRentalAgreementById(getParam(req, 'agreementId'));
  if (!agreement) throw new NotFoundError('Rental agreement');
  const tenancy = await repo.findTenancyById(agreement.tenancyId);
  if (tenancy) await assertPropertyAccess(req, tenancy.propertyId);
  const userId = assertAuth(req);
  const data = req.body;
  const updated = await repo.updateRentalAgreement(getParam(req, 'agreementId'), {
    endDate: data.endDate ? new Date(data.endDate) : null,
    monthlyRent: data.monthlyRent,
    depositAmount: data.depositAmount,
    rentDueDay: data.rentDueDay,
    paymentMethod: data.paymentMethod,
    specialConditions: data.specialConditions,
    status: data.status,
  }, userId);
  if (!updated) throw new NotFoundError('Rental agreement');
  await authz.invalidateUserPermissionCache(userId);
  res.json(updated);
}

export async function uploadLeaseDocument(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  if (data.propertyId) await assertPropertyAccess(req, data.propertyId);

  const document = await repo.createLeaseDocument({
    rentalAgreementId: data.rentalAgreementId ?? null,
    propertyId: data.propertyId ?? null,
    unitId: data.unitId ?? null,
    tenancyId: data.tenancyId ?? null,
    tenantId: data.tenantId ?? null,
    type: data.type,
    title: data.title,
    description: data.description ?? null,
    fileName: data.fileName,
    filePath: data.filePath,
    fileSizeBytes: data.fileSizeBytes ?? null,
    mimeType: data.mimeType ?? null,
    category: data.category ?? null,
    isPrivate: data.isPrivate ?? true,
    uploadedBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(document);
}

export async function listLeaseDocuments(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  const documents = await repo.findLeaseDocuments({
    rentalAgreementId: query.rentalAgreementId as string | undefined,
    propertyId: query.propertyId as string | undefined,
    unitId: query.unitId as string | undefined,
    tenancyId: query.tenancyId as string | undefined,
    limit: query.limit ? Number(query.limit) : 20,
    offset: query.offset ? Number(query.offset) : 0,
  });
  res.json(documents);
}

// ============================================================================
// INSPECTION CONTROLLERS
// ============================================================================

export async function createMoveInInspection(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertTenancyAccess(req, data.tenancyId);
  const tenant = await repo.findTenantByTenancyId(data.tenancyId);
  if (!tenant) throw new NotFoundError('Tenant for tenancy');

  const inspection = await repo.createMoveInInspection({
    tenancyId: data.tenancyId,
    tenantId: tenant.id,
    unitId: data.unitId,
    inspectionDate: new Date(data.inspectionDate),
    overallCondition: data.overallCondition,
    meterReadings: data.meterReadings,
    keyHandover: data.keyHandover,
    notes: data.notes,
    inspectorId: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(inspection);
}

export async function createMoveOutInspection(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  await assertTenancyAccess(req, data.tenancyId);
  const tenant = await repo.findTenantByTenancyId(data.tenancyId);
  if (!tenant) throw new NotFoundError('Tenant for tenancy');

  const inspection = await repo.createMoveOutInspection({
    tenancyId: data.tenancyId,
    tenantId: tenant.id,
    unitId: data.unitId,
    inspectionDate: new Date(data.inspectionDate),
    overallCondition: data.overallCondition,
    meterReadings: data.meterReadings,
    keyReturned: data.keyReturned,
    damageNotes: data.damageNotes,
    cleaningRequired: data.cleaningRequired,
    cleaningCost: data.cleaningCost,
    repairCost: data.repairCost,
    notes: data.notes,
    inspectorId: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(inspection);
}

export async function createInspectionItem(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;

  const inspection = await repo.findMoveInInspectionById(data.inspectionId);
  if (!inspection) throw new NotFoundError('Inspection');
  await assertTenancyAccess(req, inspection.tenancyId);

  await repo.createInspectionItem({
    inspectionId: data.inspectionId,
    itemCategory: data.itemCategory,
    itemName: data.itemName,
    conditionRating: data.conditionRating,
    notes: data.notes,
    photoUrl: data.photoUrl,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json({ success: true });
}

export async function getInspectionItems(req: AuthenticatedRequest, res: Response) {
  const inspection = await repo.findMoveInInspectionById(getParam(req, 'inspectionId'));
  if (!inspection) throw new NotFoundError('Inspection');
  await assertTenancyAccess(req, inspection.tenancyId);
  const items = await repo.findInspectionItems(getParam(req, 'inspectionId'));
  res.json(items);
}

// ============================================================================
// EXTENDED DASHBOARD CONTROLLER
// ============================================================================

export async function getExtendedDashboardStats(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query;
  const propertyId = query.propertyId as string | undefined;

  if (propertyId) {
    await assertPropertyAccess(req, propertyId);
  }

  const stats = await repo.getExtendedDashboardStats(propertyId);
  res.json(stats);
}
