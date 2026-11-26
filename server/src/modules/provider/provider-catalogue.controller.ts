// Provider service-catalogue controller (Task 13.4).
import type { Request, Response } from 'express';
import { ForbiddenError, ValidationError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type {
  CreateExceptionInput,
  CreateLocationInput,
  CreateOfferingInput,
  CreateServiceAreaInput,
  OperatingHoursReplaceInput,
  UpdateExceptionInput,
  UpdateLocationInput,
  UpdateOfferingInput,
  OfferingCapabilitiesInput,
  OfferingPricingInput,
  UpdateServiceAreaInput,
} from './provider-catalogue.schemas.js';
import type { OfferingStatus, ServiceDomain } from './provider-catalogue.types.js';
import * as service from './provider-catalogue.service.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function str(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

// ---- Catalogue reference ----
export async function getCatalogue(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const domain = str(req.query.domain) as ServiceDomain | undefined;
  const data = await service.getCatalogue(domain);
  res.json({ success: true, data });
}

export async function getCatalogueByDomain(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const domain = req.params.serviceType as ServiceDomain;
  const data = await service.getCatalogue(domain);
  res.json({ success: true, data });
}

// ---- Offerings ----
export async function listOfferings(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as { organizationId?: string; domain?: ServiceDomain; status?: OfferingStatus };
  const data = await service.listOfferings(userId, {
    organizationId: q.organizationId ?? null,
    domain: q.domain,
    status: q.status,
  });
  res.json({ success: true, data });
}

export async function createOffering(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const offering = await service.createOffering(userId, req.body as CreateOfferingInput);
  res.status(201).json({ success: true, data: offering });
}

export async function getOffering(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const offering = await service.getOffering(userId, req.params.serviceId as string);
  res.json({ success: true, data: offering });
}

export async function updateOffering(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const offering = await service.updateOffering(userId, req.params.serviceId as string, req.body as UpdateOfferingInput);
  res.json({ success: true, data: offering });
}

export async function activateOffering(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const offering = await service.setOfferingStatus(userId, req.params.serviceId as string, 'activate');
  res.json({ success: true, data: offering });
}

export async function pauseOffering(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { from?: string | null; to?: string | null };
  const offering = await service.setOfferingStatus(userId, req.params.serviceId as string, 'pause', {
    from: body.from ?? null,
    to: body.to ?? null,
  });
  res.json({ success: true, data: offering });
}

export async function archiveOffering(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const offering = await service.setOfferingStatus(userId, req.params.serviceId as string, 'archive');
  res.json({ success: true, data: offering });
}

// ---- Capabilities & pricing ----
export async function getCapabilities(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getCapabilities(userId, req.params.serviceId as string) });
}

export async function replaceCapabilities(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as OfferingCapabilitiesInput;
  res.json({ success: true, data: await service.replaceCapabilities(userId, req.params.serviceId as string, body.capabilities) });
}

export async function getPricing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getPricing(userId, req.params.serviceId as string) });
}

export async function setPricing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.setPricing(userId, req.params.serviceId as string, req.body as OfferingPricingInput) });
}

// ---- Locations ----
export async function listLocations(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const organisationId = str(req.query.organizationId);
  res.json({ success: true, data: await service.listLocations(userId, organisationId ?? null) });
}

export async function createLocation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const location = await service.createLocation(userId, req.body as CreateLocationInput);
  res.status(201).json({ success: true, data: location });
}

export async function updateLocation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const location = await service.updateLocation(userId, req.params.locationId as string, req.body as UpdateLocationInput);
  res.json({ success: true, data: location });
}

export async function deleteLocation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.deleteLocation(userId, req.params.locationId as string) });
}

export async function setPrimaryLocation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.setPrimaryLocation(userId, req.params.locationId as string) });
}

// ---- Service areas ----
export async function listServiceAreas(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profileId = str(req.query.profileId);
  const offeringId = str(req.query.offeringId);
  res.json({ success: true, data: await service.listServiceAreas(userId, profileId ?? null, offeringId ?? null) });
}

export async function createServiceArea(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const area = await service.createServiceArea(userId, req.body as CreateServiceAreaInput);
  res.status(201).json({ success: true, data: area });
}

export async function updateServiceArea(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const area = await service.updateServiceArea(userId, req.params.areaId as string, req.body as UpdateServiceAreaInput);
  res.json({ success: true, data: area });
}

export async function deleteServiceArea(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.deleteServiceArea(userId, req.params.areaId as string) });
}

// ---- Availability ----
export async function getAvailability(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profileId = str(req.query.profileId);
  const offeringId = str(req.query.offeringId);
  res.json({ success: true, data: await service.getAvailability(userId, profileId ?? null, offeringId ?? null) });
}

export async function replaceAvailability(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.replaceAvailability(userId, req.body as OperatingHoursReplaceInput) });
}

export async function listExceptions(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const profileId = req.query.profileId as string;
  if (!profileId) throw new ValidationError('profileId is required');
  const offeringId = str(req.query.offeringId);
  res.json({ success: true, data: await service.listExceptions(userId, profileId, offeringId ?? null) });
}

export async function createException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const exception = await service.createException(userId, req.body as CreateExceptionInput);
  res.status(201).json({ success: true, data: exception });
}

export async function updateException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const exception = await service.updateException(userId, req.params.exceptionId as string, req.body as UpdateExceptionInput);
  res.json({ success: true, data: exception });
}

export async function deleteException(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.deleteException(userId, req.params.exceptionId as string) });
}