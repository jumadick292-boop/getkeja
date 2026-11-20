import { Router } from 'express';
import { requireAuth } from './authorization.middleware.js';
import {
  createPropertySchema,
  updatePropertySchema,
  propertyQuerySchema,
  createUnitSchema,
  updateUnitSchema,
  unitQuerySchema,
  createTenancySchema,
  updateTenancySchema,
  tenancyQuerySchema,
  addTenancyParticipantSchema,
  updateTenancyParticipantSchema,
  createPropertyDocumentSchema,
  updatePropertyDocumentSchema,
  createSiteVisitSchema,
  updateSiteVisitSchema,
  siteVisitQuerySchema,
  createRentalApplicationSchema,
  updateRentalApplicationSchema,
  rentalApplicationQuerySchema,
} from './auth.schema.js';
import { validate } from '../../middleware/validate.js';
import {
  createProperty,
  getProperty,
  updateProperty,
  deleteProperty,
  listProperties,
  createUnit,
  getUnit,
  updateUnit,
  deleteUnit,
  listUnits,
  createTenancy,
  getTenancy,
  updateTenancy,
  deleteTenancy,
  listTenancies,
  addTenancyParticipant,
  getTenancyParticipants,
  updateTenancyParticipant,
  removeTenancyParticipant,
  createPropertyDocument,
  getPropertyDocument,
  updatePropertyDocument,
  deletePropertyDocument,
  listPropertyDocuments,
  getDocumentSignedUrl,
  accessDocumentViaSignedUrl,
  createSiteVisit,
  getSiteVisit,
  updateSiteVisit,
  deleteSiteVisit,
  listSiteVisits,
  createRentalApplication,
  getRentalApplication,
  updateRentalApplication,
  deleteRentalApplication,
  listRentalApplications,
} from './resource.controller.js';
import {
  requirePropertyAccess,
  requireUnitAccess,
  requireTenancyAccess,
  requireDocumentAccess,
  requireSiteVisitAccess,
  requireRentalApplicationAccess,
} from './authorization.middleware.js';

export function createResourceRouter(): Router {
  const router = Router();

  router.use(requireAuth);

  // Properties
  router.post('/properties', validate(createPropertySchema), createProperty);
  router.get('/properties', validate(propertyQuerySchema), listProperties);
  router.get('/properties/:propertyId', requirePropertyAccess('propertyId'), getProperty);
  router.patch('/properties/:propertyId', requirePropertyAccess('propertyId'), validate(updatePropertySchema), updateProperty);
  router.delete('/properties/:propertyId', requirePropertyAccess('propertyId'), deleteProperty);

  // Units
  router.post('/units', validate(createUnitSchema), createUnit);
  router.get('/units', validate(unitQuerySchema), listUnits);
  router.get('/units/:unitId', requireUnitAccess('unitId'), getUnit);
  router.patch('/units/:unitId', requireUnitAccess('unitId'), validate(updateUnitSchema), updateUnit);
  router.delete('/units/:unitId', requireUnitAccess('unitId'), deleteUnit);

  // Tenancies
  router.post('/tenancies', validate(createTenancySchema), createTenancy);
  router.get('/tenancies', validate(tenancyQuerySchema), listTenancies);
  router.get('/tenancies/:tenancyId', requireTenancyAccess('tenancyId'), getTenancy);
  router.patch('/tenancies/:tenancyId', requireTenancyAccess('tenancyId'), validate(updateTenancySchema), updateTenancy);
  router.delete('/tenancies/:tenancyId', requireTenancyAccess('tenancyId'), deleteTenancy);

  // Tenancy participants
  router.post('/tenancies/:tenancyId/participants', requireTenancyAccess('tenancyId'), validate(addTenancyParticipantSchema), addTenancyParticipant);
  router.get('/tenancies/:tenancyId/participants', requireTenancyAccess('tenancyId'), getTenancyParticipants);
  router.patch('/tenancies/:tenancyId/participants/:participantId', requireTenancyAccess('tenancyId'), validate(updateTenancyParticipantSchema), updateTenancyParticipant);
  router.delete('/tenancies/:tenancyId/participants/:participantId', requireTenancyAccess('tenancyId'), removeTenancyParticipant);

  // Property documents
  router.post('/documents', validate(createPropertyDocumentSchema), createPropertyDocument);
  router.get('/documents', listPropertyDocuments);
  router.get('/documents/:documentId', requireDocumentAccess('documentId'), getPropertyDocument);
  router.patch('/documents/:documentId', requireDocumentAccess('documentId'), validate(updatePropertyDocumentSchema), updatePropertyDocument);
  router.delete('/documents/:documentId', requireDocumentAccess('documentId'), deletePropertyDocument);

  // Document signed URLs
  router.get('/documents/:documentId/signed-url', requireDocumentAccess('documentId'), getDocumentSignedUrl);
  router.get('/documents/:documentId/signed', accessDocumentViaSignedUrl);

  // Site visits
  router.post('/site-visits', validate(createSiteVisitSchema), createSiteVisit);
  router.get('/site-visits', validate(siteVisitQuerySchema), listSiteVisits);
  router.get('/site-visits/:visitId', requireSiteVisitAccess('visitId'), getSiteVisit);
  router.patch('/site-visits/:visitId', requireSiteVisitAccess('visitId'), validate(updateSiteVisitSchema), updateSiteVisit);
  router.delete('/site-visits/:visitId', requireSiteVisitAccess('visitId'), deleteSiteVisit);

  // Rental applications
  router.post('/rental-applications', validate(createRentalApplicationSchema), createRentalApplication);
  router.get('/rental-applications', validate(rentalApplicationQuerySchema), listRentalApplications);
  router.get('/rental-applications/:applicationId', requireRentalApplicationAccess('applicationId'), getRentalApplication);
  router.patch('/rental-applications/:applicationId', requireRentalApplicationAccess('applicationId'), validate(updateRentalApplicationSchema), updateRentalApplication);
  router.delete('/rental-applications/:applicationId', requireRentalApplicationAccess('applicationId'), deleteRentalApplication);

  return router;
}