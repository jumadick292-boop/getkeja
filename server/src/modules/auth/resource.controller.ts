import type { Request, Response } from 'express';
import type { AuthUser, Session } from './auth.types.js';
import { NotFoundError, ForbiddenError } from '../../shared/errors.js';
import * as repo from './auth.repository.js';
import * as authz from './authorization.service.js';
import * as signedUrlService from './document-signed-url.service.js';
import { validate } from '../../middleware/validate.js';
import { randomUUID } from 'crypto';

function getParam(req: AuthenticatedRequest, name: string): string {
  const value = req.params[name];
  if (value === undefined) return '';
  return (Array.isArray(value) ? value[0] : value) as string;
}

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
  session?: Session;
}

function assertAuth(req: AuthenticatedRequest) {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

async function assertPropertyAccess(req: AuthenticatedRequest, propertyId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessProperty(userId, propertyId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
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

async function assertDocumentAccess(req: AuthenticatedRequest, documentId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessPropertyDocument(userId, documentId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

async function assertSiteVisitAccess(req: AuthenticatedRequest, visitId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessSiteVisit(userId, visitId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

async function assertRentalApplicationAccess(req: AuthenticatedRequest, applicationId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessRentalApplication(userId, applicationId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

export async function createProperty(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const data = req.body;
  const property = await repo.createProperty({
    organisationId: data.organisationId ?? null,
    title: data.title,
    description: data.description ?? null,
    propertyType: data.propertyType,
    address: data.address,
    city: data.city,
    county: data.county,
    country: data.country ?? 'KE',
    latitude: data.latitude ?? null,
    longitude: data.longitude ?? null,
    amenities: data.amenities ?? null,
    features: data.features ?? null,
    images: data.images ?? null,
    createdBy: userId,
  });
  await authz.invalidateUserPermissionCache(userId);
  res.status(201).json(property);
}

export async function getProperty(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, getParam(req, 'propertyId'));
  const property = await repo.findPropertyById(getParam(req, 'propertyId'));
  if (!property) throw new NotFoundError('Property');
  res.json(property);
}

export async function updateProperty(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, getParam(req, 'propertyId'));
  const data = req.body;
  const userId = assertAuth(req);
  const property = await repo.updateProperty(getParam(req, 'propertyId'), data, userId);
  if (!property) throw new NotFoundError('Property');
  await authz.invalidateUserPermissionCache(userId);
  res.json(property);
}

export async function deleteProperty(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, getParam(req, 'propertyId'));
  const userId = assertAuth(req);
  await repo.deleteProperty(getParam(req, 'propertyId'));
  await authz.invalidateUserPermissionCache(userId);
  res.status(204).send();
}

export async function listProperties(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  const userId = assertAuth(req);

  let properties;
  if (query.organisationId) {
    const isMember = await authz.isOrganizationMember(userId, query.organisationId as string);
    if (!isMember) throw new ForbiddenError('Not a member of this organization');
    properties = await repo.findPropertiesByOrganisation(query.organisationId as string);
  } else {
    const orgIds = await authz.getUserOrganizations(userId);
    properties = await repo.findPropertiesByUserOrgs(orgIds, query);
  }
  res.json(properties);
}

export async function createUnit(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, req.body.propertyId);
  const userId = assertAuth(req);
  const data = req.body;
  const unit = await repo.createUnit({
    propertyId: data.propertyId,
    unitNumber: data.unitNumber,
    unitType: data.unitType,
    floorNumber: data.floor ?? null,
    bedrooms: data.bedrooms ?? 0,
    bathrooms: data.bathrooms ?? 0,
    areaSqm: data.areaSqm ?? null,
    rentAmount: data.rentAmount,
    depositAmount: data.depositAmount ?? 0,
    description: data.description ?? null,
    amenities: data.amenities ?? null,
    features: data.features ?? null,
    images: data.images ?? null,
    hasSeparateMeter: false,
    meterNumber: null,
    createdBy: userId,
  });
  res.status(201).json(unit);
}

export async function getUnit(req: AuthenticatedRequest, res: Response) {
  await assertUnitAccess(req, getParam(req, 'unitId'));
  const unit = await repo.findUnitById(getParam(req, 'unitId'));
  if (!unit) throw new NotFoundError('Unit');
  res.json(unit);
}

export async function updateUnit(req: AuthenticatedRequest, res: Response) {
  await assertUnitAccess(req, getParam(req, 'unitId'));
  const data = req.body;
  const userId = assertAuth(req);
  const unit = await repo.updateUnit(getParam(req, 'unitId'), data, userId);
  if (!unit) throw new NotFoundError('Unit');
  res.json(unit);
}

export async function deleteUnit(req: AuthenticatedRequest, res: Response) {
  await assertUnitAccess(req, getParam(req, 'unitId'));
  await repo.deleteUnit(getParam(req, 'unitId'));
  res.status(204).send();
}

export async function listUnits(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  if (query.propertyId) {
    await assertPropertyAccess(req, query.propertyId as string);
    const units = await repo.findUnitsByProperty(query.propertyId as string);
    res.json(units);
  } else {
    const userId = assertAuth(req);
    const orgIds = await authz.getUserOrganizations(userId);
    const units = await repo.findUnitsByUserOrgs(orgIds, query);
    res.json(units);
  }
}

export async function createTenancy(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, req.body.propertyId);
  await assertUnitAccess(req, req.body.unitId);
  const userId = assertAuth(req);
  const data = req.body;
  const tenancy = await repo.createTenancy({
    propertyId: data.propertyId,
    unitId: data.unitId,
    tenancyType: data.tenancyType ?? 'residential',
    startDate: new Date(data.startDate),
    endDate: data.endDate ? new Date(data.endDate) : null,
    noticePeriodDays: data.noticePeriodDays ?? 30,
    rentAmount: data.rentAmount,
    depositAmount: data.depositAmount ?? 0,
    depositHeldBy: data.depositHeldBy ?? null,
    depositSchemeReference: data.depositSchemeReference ?? null,
    rentDueDay: data.rentDueDay ?? 1,
    paymentMethod: data.paymentMethod ?? null,
    paymentReference: data.paymentReference ?? null,
    termsDocumentUrl: data.termsDocumentUrl ?? null,
    specialConditions: data.specialConditions ?? null,
    managedByUserId: data.managedByUserId ?? null,
    managedByOrganisationId: data.managedByOrganisationId ?? null,
    createdBy: userId,
  });
  res.status(201).json(tenancy);
}

export async function getTenancy(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  const tenancy = await repo.findTenancyById(getParam(req, 'tenancyId'));
  if (!tenancy) throw new NotFoundError('Tenancy');
  res.json(tenancy);
}

export async function updateTenancy(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  const data = req.body;
  const userId = assertAuth(req);
  const tenancy = await repo.updateTenancy(getParam(req, 'tenancyId'), data, userId);
  if (!tenancy) throw new NotFoundError('Tenancy');
  res.json(tenancy);
}

export async function deleteTenancy(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  await repo.deleteTenancy(getParam(req, 'tenancyId'));
  res.status(204).send();
}

export async function listTenancies(req: AuthenticatedRequest, res: Response) {
  const query = req.query;
  if (query.propertyId) {
    await assertPropertyAccess(req, query.propertyId as string);
    const tenancies = await repo.findTenanciesByProperty(query.propertyId as string);
    res.json(tenancies);
  } else if (query.unitId) {
    await assertUnitAccess(req, query.unitId as string);
    const tenancies = await repo.findTenanciesByUnit(query.unitId as string, query);
    res.json(tenancies);
  } else {
    const userId = assertAuth(req);
    const orgIds = await authz.getUserOrganizations(userId);
    const tenancies = await repo.findTenanciesByUserOrgs(orgIds, query);
    res.json(tenancies);
  }
}

export async function addTenancyParticipant(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  const userId = assertAuth(req);
  const data = req.body;
  const participant = await repo.addTenancyParticipant({
    tenancyId: getParam(req, 'tenancyId'),
    userId: data.userId ?? null,
    fullName: data.fullName ?? null,
    email: data.email ?? null,
    phone: data.phone ?? null,
    idNumber: data.idNumber ?? null,
    idType: data.idType ?? null,
    role: data.role ?? 'co_tenant',
    isPrimary: data.isPrimary ?? false,
    canAccessDocuments: data.canAccessDocuments ?? true,
    canReceiveNotices: data.canReceiveNotices ?? true,
    canAuthorizeRepairs: data.canAuthorizeRepairs ?? false,
    addedBy: userId,
  });
  res.status(201).json(participant);
}

export async function getTenancyParticipants(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  const participants = await repo.findTenancyParticipants(getParam(req, 'tenancyId'));
  res.json(participants);
}

export async function updateTenancyParticipant(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  const data = req.body;
  const userId = assertAuth(req);
  const participant = await repo.updateTenancyParticipant(getParam(req, 'participantId'), {
    ...data,
    removedBy: data.status === 'removed' ? userId : undefined,
  }, userId);
  if (!participant) throw new NotFoundError('Participant');
  res.json(participant);
}

export async function removeTenancyParticipant(req: AuthenticatedRequest, res: Response) {
  await assertTenancyAccess(req, getParam(req, 'tenancyId'));
  const userId = assertAuth(req);
  await repo.removeTenancyParticipant(getParam(req, 'participantId'), userId);
  res.status(204).send();
}

export async function createPropertyDocument(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, req.body.propertyId);
  if (req.body.tenancyId) {
    await assertTenancyAccess(req, req.body.tenancyId);
  }
  if (req.body.unitId) {
    await assertUnitAccess(req, req.body.unitId);
  }
  const userId = assertAuth(req);
  const data = req.body;
  // Map fileUrl to filePath, fileName, etc.
  const document = await repo.createPropertyDocument({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    tenancyId: data.tenancyId ?? null,
    title: data.title,
    description: data.description ?? null,
    category: data.type, // schema uses 'type', repo uses 'category'
    visibility: data.visibility ?? 'participants_only',
    filePath: data.fileUrl,
    fileName: data.fileUrl.split('/').pop() ?? 'document',
    fileSize: data.fileSize ?? 0,
    mimeType: data.mimeType ?? 'application/octet-stream',
    fileHash: '',
    allowedRoles: [],
    allowedUserIds: [],
    allowedOrganisationIds: [],
    uploadedBy: userId,
    expiresAt: data.expiresAt ? new Date(data.expiresAt) : null,
  });
  res.status(201).json(document);
}

export async function getPropertyDocument(req: AuthenticatedRequest, res: Response) {
  await assertDocumentAccess(req, getParam(req, 'documentId'));
  const document = await repo.findPropertyDocumentById(getParam(req, 'documentId'));
  if (!document) throw new NotFoundError('Document');
  res.json(document);
}

export async function updatePropertyDocument(req: AuthenticatedRequest, res: Response) {
  await assertDocumentAccess(req, getParam(req, 'documentId'));
  const data = req.body;
  const userId = assertAuth(req);
  const document = await repo.updatePropertyDocument(getParam(req, 'documentId'), data, userId);
  if (!document) throw new NotFoundError('Document');
  res.json(document);
}

export async function deletePropertyDocument(req: AuthenticatedRequest, res: Response) {
  await assertDocumentAccess(req, getParam(req, 'documentId'));
  await repo.deletePropertyDocument(getParam(req, 'documentId'));
  res.status(204).send();
}

export async function listPropertyDocuments(req: AuthenticatedRequest, res: Response) {
  const { propertyId, tenancyId, unitId, type, visibility, limit = 20, offset = 0 } = req.query;

  if (propertyId) {
    await assertPropertyAccess(req, propertyId as string);
    const documents = await repo.findPropertyDocuments(propertyId as string);
    res.json(documents);
  } else if (tenancyId) {
    await assertTenancyAccess(req, tenancyId as string);
    const documents = await repo.findPropertyDocumentsByTenancy(tenancyId as string);
    res.json(documents);
  } else {
    const userId = assertAuth(req);
    const orgIds = await authz.getUserOrganizations(userId);
    const documents = await repo.findPropertyDocumentsByUserOrgs(orgIds, { limit: Number(limit), offset: Number(offset) });
    res.json(documents);
  }
}

export async function getDocumentSignedUrl(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const documentId = getParam(req, 'documentId');
  const purpose = (req.query.purpose as 'download' | 'view') || 'view';
  const ttlSeconds = req.query.ttl ? Number(req.query.ttl) : undefined;

  const result = await signedUrlService.generateDocumentSignedUrl(documentId, userId, purpose, ttlSeconds);
  if (!result) {
    throw new NotFoundError('Document not found or access denied');
  }

  res.json(result);
}

export async function accessDocumentViaSignedUrl(req: Request, res: Response) {
  const token = req.query.token as string;
  if (!token) {
    throw new NotFoundError('Invalid signed URL');
  }

  const payload = await signedUrlService.verifySignedDocumentUrl(token);
  if (!payload) {
    throw new NotFoundError('Invalid or expired signed URL');
  }

  const document = await repo.findPropertyDocumentById(payload.documentId);
  if (!document) {
    throw new NotFoundError('Document not found');
  }

  const canAccess = await signedUrlService.canAccessDocumentViaSignedUrl(document, payload);
  if (!canAccess) {
    throw new NotFoundError('Access denied');
  }

  // In a real implementation, you'd serve the file from storage
  // For now, return the document metadata with the file path
  res.json({
    document: {
      id: document.id,
      title: document.title,
      fileName: document.fileName,
      fileSize: document.fileSize,
      mimeType: document.mimeType,
      filePath: document.filePath,
    },
    purpose: payload.purpose,
  });
}

export async function createSiteVisit(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, req.body.propertyId);
  if (req.body.unitId) {
    await assertUnitAccess(req, req.body.unitId);
  }
  const userId = assertAuth(req);
  const data = req.body;
  const visit = await repo.createSiteVisit({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    userId: userId, // The current user is the visitor
    visitorName: data.visitorName,
    visitorEmail: data.visitorEmail ?? null,
    visitorPhone: data.visitorPhone,
    scheduledAt: new Date(data.scheduledAt),
    durationMinutes: data.durationMinutes ?? 30,
    hostedByUserId: data.hostedByUserId ?? null,
    hostedByOrganisationId: data.hostedByOrganisationId ?? null,
    visitorNotes: data.visitorNotes ?? null,
    createdBy: userId,
  });
  res.status(201).json(visit);
}

export async function getSiteVisit(req: AuthenticatedRequest, res: Response) {
  await assertSiteVisitAccess(req, getParam(req, 'visitId'));
  const visit = await repo.findSiteVisitById(getParam(req, 'visitId'));
  if (!visit) throw new NotFoundError('Site visit');
  res.json(visit);
}

export async function updateSiteVisit(req: AuthenticatedRequest, res: Response) {
  await assertSiteVisitAccess(req, getParam(req, 'visitId'));
  const data = req.body;
  const userId = assertAuth(req);
  const visit = await repo.updateSiteVisit(getParam(req, 'visitId'), data, userId);
  if (!visit) throw new NotFoundError('Site visit');
  res.json(visit);
}

export async function deleteSiteVisit(req: AuthenticatedRequest, res: Response) {
  await assertSiteVisitAccess(req, getParam(req, 'visitId'));
  await repo.deleteSiteVisit(getParam(req, 'visitId'));
  res.status(204).send();
}

export async function listSiteVisits(req: AuthenticatedRequest, res: Response) {
  const query = req.query;

  if (query.propertyId) {
    await assertPropertyAccess(req, query.propertyId as string);
    const visits = await repo.findSiteVisitsByProperty(query.propertyId as string);
    res.json(visits);
  } else if (query.hostedByUserId) {
    const visits = await repo.findSiteVisitsByUser(query.hostedByUserId as string);
    res.json(visits);
  } else {
    const userId = assertAuth(req);
    const visits = await repo.findSiteVisitsByUser(userId);
    res.json(visits);
  }
}

export async function createRentalApplication(req: AuthenticatedRequest, res: Response) {
  await assertPropertyAccess(req, req.body.propertyId);
  if (req.body.unitId) {
    await assertUnitAccess(req, req.body.unitId);
  }
  const userId = assertAuth(req);
  const data = req.body;
  const application = await repo.createRentalApplication({
    propertyId: data.propertyId,
    unitId: data.unitId ?? null,
    userId: userId,
    applicantName: data.applicantName,
    applicantEmail: data.applicantEmail,
    applicantPhone: data.applicantPhone,
    applicantIdNumber: data.applicantIdNumber ?? null,
    applicantIdType: data.applicantIdType ?? null,
    preferredStartDate: data.preferredStartDate ? new Date(data.preferredStartDate) : null,
    preferredEndDate: data.preferredEndDate ? new Date(data.preferredEndDate) : null,
    proposedRentAmount: data.proposedRentAmount ?? null,
    documents: data.documents ?? null,
    employerName: data.employerName ?? null,
    employerContact: data.employerContact ?? null,
    monthlyIncome: data.monthlyIncome ?? null,
    previousLandlordName: data.previousLandlordName ?? null,
    previousLandlordContact: data.previousLandlordContact ?? null,
    guarantorName: data.guarantorName ?? null,
    guarantorEmail: data.guarantorEmail ?? null,
    guarantorPhone: data.guarantorPhone ?? null,
    guarantorIdNumber: data.guarantorIdNumber ?? null,
    guarantorRelationship: data.guarantorRelationship ?? null,
  });
  res.status(201).json(application);
}

export async function getRentalApplication(req: AuthenticatedRequest, res: Response) {
  await assertRentalApplicationAccess(req, getParam(req, 'applicationId'));
  const application = await repo.findRentalApplicationById(getParam(req, 'applicationId'));
  if (!application) throw new NotFoundError('Rental application');
  res.json(application);
}

export async function updateRentalApplication(req: AuthenticatedRequest, res: Response) {
  await assertRentalApplicationAccess(req, getParam(req, 'applicationId'));
  const data = req.body;
  const userId = assertAuth(req);
  const application = await repo.updateRentalApplication(getParam(req, 'applicationId'), data, userId);
  if (!application) throw new NotFoundError('Rental application');
  res.json(application);
}

export async function deleteRentalApplication(req: AuthenticatedRequest, res: Response) {
  await assertRentalApplicationAccess(req, getParam(req, 'applicationId'));
  await repo.deleteRentalApplication(getParam(req, 'applicationId'));
  res.status(204).send();
}

export async function listRentalApplications(req: AuthenticatedRequest, res: Response) {
  const query = req.query;

  if (query.propertyId) {
    await assertPropertyAccess(req, query.propertyId as string);
    const applications = await repo.findRentalApplicationsByProperty(query.propertyId as string);
    res.json(applications);
  } else {
    const userId = assertAuth(req);
    const applications = await repo.findRentalApplicationsByUser(userId);
    res.json(applications);
  }
}