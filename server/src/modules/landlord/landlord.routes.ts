import { Router } from 'express';
import { requireAuth } from '../auth/authorization.middleware.js';
import {
  requirePropertyAccess,
  requireUnitAccess,
  requireTenancyAccess,
  requireSiteVisitAccess,
} from '../auth/authorization.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  createListingSchema,
  updateListingSchema,
  publishListingSchema,
  pauseListingSchema,
  resumeListingSchema,
  withdrawListingSchema,
  archiveListingSchema,
  listingQuerySchema,
  confirmSiteVisitSchema,
  declineSiteVisitSchema,
  rescheduleSiteVisitSchema,
  cancelSiteVisitSchema,
  completeSiteVisitSchema,
  markNoShowSchema,
  propertyIdParamSchema,
  availabilityRuleIdParamSchema,
  availabilityExceptionIdParamSchema,
  upsertAvailabilityRuleSchema,
  upsertAvailabilityExceptionSchema,
  siteVisitListQuerySchema,
  siteVisitIdParamSchema,
  createTenantSchema,
  updateTenantSchema,
  tenantQuerySchema,
  createGarbageProviderSchema,
  updateGarbageProviderSchema,
  garbageProviderQuerySchema,
  createGarbageAssignmentSchema,
  updateGarbageAssignmentSchema,
  garbageAssignmentQuerySchema,
  createGarbageCollectionRequestSchema,
  updateGarbageCollectionRequestSchema,
  garbageCollectionRequestQuerySchema,
  dashboardQuerySchema,
  // New schemas
  createPropertySchema,
  updatePropertySchema,
  propertyQuerySchema,
  createUnitSchema,
  updateUnitSchema,
  unitQuerySchema,
  createPropertyDocumentSchema,
  updatePropertyDocumentSchema,
  createEnquirySchema,
  updateEnquirySchema,
  enquiryQuerySchema,
  enquiryNoteSchema,
  createConversationSchema,
  sendMessageSchema,
  conversationQuerySchema,
  createRentalProposalSchema,
  updateRentalProposalSchema,
  rentalProposalActionSchema,
  rentalProposalQuerySchema,
  createInvoiceSchema,
  createInvoiceItemSchema,
  recordPaymentSchema,
  invoiceQuerySchema,
  reportIssueSchema,
  updateIssueSchema,
  issueQuerySchema,
  createRentalAgreementSchema,
  updateRentalAgreementSchema,
  uploadLeaseDocumentSchema,
  createMoveInInspectionSchema,
  createMoveOutInspectionSchema,
  createInspectionItemSchema,
} from './landlord.schema.js';
import {
  createListing,
  getListing,
  updateListing,
  deleteListing,
  listListings,
  publishListing,
  pauseListing,
  resumeListing,
  withdrawListing,
  archiveListing,
  confirmSiteVisit,
  declineSiteVisit,
  completeSiteVisit,
  markSiteVisitNoShow,
  listSiteVisitAvailability,
  upsertSiteVisitAvailabilityRule,
  deleteSiteVisitAvailabilityRule,
  upsertSiteVisitAvailabilityException,
  deleteSiteVisitAvailabilityException,
  rescheduleSiteVisit,
  cancelSiteVisitByLandlord,
  listLandlordSiteVisits,
  getLandlordSiteVisit,
  createTenant,
  createTenantSafe,
  getTenant,
  updateTenant,
  deleteTenant,
  listTenants,
  createGarbageProvider,
  getGarbageProvider,
  updateGarbageProvider,
  deleteGarbageProvider,
  listGarbageProviders,
  createGarbageAssignment,
  getGarbageAssignment,
  updateGarbageAssignment,
  deleteGarbageAssignment,
  listGarbageAssignments,
  createGarbageCollectionRequest,
  getGarbageCollectionRequest,
  updateGarbageCollectionRequest,
  deleteGarbageCollectionRequest,
  listGarbageCollectionRequests,
  getDashboardStats,
  // New controllers
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
  createPropertyDocument,
  listPropertyDocuments,
  createEnquiry,
  getEnquiry,
  updateEnquiry,
  listEnquiries,
  addEnquiryNote,
  getEnquiryNotes,
  createConversation,
  getConversation,
  listConversations,
  getConversationParticipants,
  sendMessage,
  listMessages,
  markMessageRead,
  createRentalProposal,
  getRentalProposal,
  updateRentalProposal,
  listRentalProposals,
  actionRentalProposal,
  createInvoice,
  getInvoice,
  listInvoices,
  recordPayment,
  listRentLedger,
  reportIssue,
  getIssue,
  updateIssue,
  listIssues,
  createRentalAgreement,
  getRentalAgreement,
  listRentalAgreements,
  updateRentalAgreement,
  uploadLeaseDocument,
  listLeaseDocuments,
  createMoveInInspection,
  createMoveOutInspection,
  createInspectionItem,
  getInspectionItems,
  getExtendedDashboardStats,
} from './landlord.controller.js';

export function createLandlordRouter(): Router {
  const router = Router();

  router.use(requireAuth);

  // ============================================================================
  // Property Listings
  // ============================================================================
  router.post('/listings', validate(createListingSchema), createListing);
  router.get('/listings', validate(listingQuerySchema, 'query'), listListings);
  router.get('/listings/:listingId', getListing);
  router.patch('/listings/:listingId', validate(updateListingSchema), updateListing);
  router.delete('/listings/:listingId', deleteListing);

  // Listing status transitions
  router.post('/listings/:listingId/publish', validate(publishListingSchema), publishListing);
  router.post('/listings/:listingId/pause', validate(pauseListingSchema), pauseListing);
  router.post('/listings/:listingId/resume', validate(resumeListingSchema), resumeListing);
  router.post('/listings/:listingId/withdraw', validate(withdrawListingSchema), withdrawListing);
  router.post('/listings/:listingId/archive', validate(archiveListingSchema), archiveListing);

  // ============================================================================
  // Properties
  // ============================================================================
  router.post('/properties', validate(createPropertySchema), createProperty);
  router.get('/properties', validate(propertyQuerySchema, 'query'), listProperties);
  router.get('/properties/:propertyId', getProperty);
  router.patch('/properties/:propertyId', validate(updatePropertySchema), updateProperty);
  router.delete('/properties/:propertyId', deleteProperty);

  // ============================================================================
  // Units
  // ============================================================================
  router.post('/units', validate(createUnitSchema), createUnit);
  router.get('/units', validate(unitQuerySchema, 'query'), listUnits);
  router.get('/units/:unitId', getUnit);
  router.patch('/units/:unitId', validate(updateUnitSchema), updateUnit);
  router.delete('/units/:unitId', deleteUnit);

  // ============================================================================
  // Property Documents
  // ============================================================================
  router.post('/properties/documents', validate(createPropertyDocumentSchema), createPropertyDocument);
  router.get('/properties/documents', validate(propertyQuerySchema, 'query'), listPropertyDocuments);

  // ============================================================================
  // Site Visit Management (landlord actions)
  // ============================================================================
  router.post(
    '/site-visits/:visitId/confirm',
    requireSiteVisitAccess('visitId', 'site_visit.manage'),
    validate(confirmSiteVisitSchema),
    confirmSiteVisit,
  );
  router.post(
    '/site-visits/:visitId/decline',
    requireSiteVisitAccess('visitId', 'site_visit.manage'),
    validate(declineSiteVisitSchema),
    declineSiteVisit,
  );
  router.post(
    '/site-visits/:visitId/reschedule',
    requireSiteVisitAccess('visitId', 'site_visit.manage'),
    validate(rescheduleSiteVisitSchema),
    rescheduleSiteVisit,
  );
  router.post(
    '/site-visits/:visitId/cancel',
    requireSiteVisitAccess('visitId', 'site_visit.manage'),
    validate(cancelSiteVisitSchema),
    cancelSiteVisitByLandlord,
  );
  router.post(
    '/site-visits/:visitId/complete',
    requireSiteVisitAccess('visitId', 'site_visit.manage'),
    validate(completeSiteVisitSchema),
    completeSiteVisit,
  );
  router.post(
    '/site-visits/:visitId/no-show',
    requireSiteVisitAccess('visitId', 'site_visit.manage'),
    validate(markNoShowSchema),
    markSiteVisitNoShow,
  );
  router.get(
    '/site-visits',
    validate(siteVisitListQuerySchema, 'query'),
    listLandlordSiteVisits,
  );
  router.get(
    '/site-visits/:visitId',
    validate(siteVisitIdParamSchema, 'params'),
    getLandlordSiteVisit,
  );

  // ============================================================================
  // Site visit availability (rules and blackout exceptions)
  // ============================================================================
  router.get(
    '/properties/:propertyId/site-visit-availability',
    validate(propertyIdParamSchema, 'params'),
    listSiteVisitAvailability,
  );
  router.put(
    '/properties/:propertyId/site-visit-availability/rules',
    validate(propertyIdParamSchema, 'params'),
    validate(upsertAvailabilityRuleSchema),
    upsertSiteVisitAvailabilityRule,
  );
  router.delete(
    '/properties/:propertyId/site-visit-availability/rules/:ruleId',
    validate(availabilityRuleIdParamSchema, 'params'),
    deleteSiteVisitAvailabilityRule,
  );
  router.put(
    '/properties/:propertyId/site-visit-availability/exceptions',
    validate(propertyIdParamSchema, 'params'),
    validate(upsertAvailabilityExceptionSchema),
    upsertSiteVisitAvailabilityException,
  );
  router.delete(
    '/properties/:propertyId/site-visit-availability/exceptions/:exceptionId',
    validate(availabilityExceptionIdParamSchema, 'params'),
    deleteSiteVisitAvailabilityException,
  );

  // ============================================================================
  // Tenants
  // ============================================================================
  router.post('/tenants', validate(createTenantSchema), createTenantSafe);
  router.get('/tenants', validate(tenantQuerySchema, 'query'), listTenants);
  router.get('/tenants/:tenantId', getTenant);
  router.patch('/tenants/:tenantId', validate(updateTenantSchema), updateTenant);
  router.delete('/tenants/:tenantId', deleteTenant);

  // ============================================================================
  // Garbage Providers
  // ============================================================================
  router.post('/garbage-providers', validate(createGarbageProviderSchema), createGarbageProvider);
  router.get('/garbage-providers', validate(garbageProviderQuerySchema, 'query'), listGarbageProviders);
  router.get('/garbage-providers/:providerId', getGarbageProvider);
  router.patch('/garbage-providers/:providerId', validate(updateGarbageProviderSchema), updateGarbageProvider);
  router.delete('/garbage-providers/:providerId', deleteGarbageProvider);

  // ============================================================================
  // Garbage Assignments
  // ============================================================================
  router.post('/garbage-assignments', validate(createGarbageAssignmentSchema), createGarbageAssignment);
  router.get('/garbage-assignments', validate(garbageAssignmentQuerySchema, 'query'), listGarbageAssignments);
  router.get('/garbage-assignments/:assignmentId', getGarbageAssignment);
  router.patch('/garbage-assignments/:assignmentId', validate(updateGarbageAssignmentSchema), updateGarbageAssignment);
  router.delete('/garbage-assignments/:assignmentId', deleteGarbageAssignment);

  // ============================================================================
  // Garbage Collection Requests
  // ============================================================================
  router.post('/garbage-collection-requests', validate(createGarbageCollectionRequestSchema), createGarbageCollectionRequest);
  router.get('/garbage-collection-requests', validate(garbageCollectionRequestQuerySchema, 'query'), listGarbageCollectionRequests);
  router.get('/garbage-collection-requests/:requestId', getGarbageCollectionRequest);
  router.patch('/garbage-collection-requests/:requestId', validate(updateGarbageCollectionRequestSchema), updateGarbageCollectionRequest);
  router.delete('/garbage-collection-requests/:requestId', deleteGarbageCollectionRequest);

  // ============================================================================
  // Enquiries / CRM
  // ============================================================================
  router.post('/enquiries', validate(createEnquirySchema), createEnquiry);
  router.get('/enquiries', validate(enquiryQuerySchema, 'query'), listEnquiries);
  router.get('/enquiries/:enquiryId', getEnquiry);
  router.patch('/enquiries/:enquiryId', validate(updateEnquirySchema), updateEnquiry);
  router.post('/enquiries/:enquiryId/notes', validate(enquiryNoteSchema), addEnquiryNote);
  router.get('/enquiries/:enquiryId/notes', getEnquiryNotes);

  // ============================================================================
  // Conversations
  // ============================================================================
  router.post('/conversations', validate(createConversationSchema), createConversation);
  router.get('/conversations', validate(conversationQuerySchema, 'query'), listConversations);
  router.get('/conversations/:conversationId', getConversation);
  router.get('/conversations/:conversationId/participants', getConversationParticipants);

  // ============================================================================
  // Messages
  // ============================================================================
  router.post('/messages', validate(sendMessageSchema), sendMessage);
  router.get('/conversations/:conversationId/messages', listMessages);
  router.post('/messages/:messageId/read', markMessageRead);

  // ============================================================================
  // Rental Proposals
  // ============================================================================
  router.post('/rental-proposals', validate(createRentalProposalSchema), createRentalProposal);
  router.get('/rental-proposals', validate(rentalProposalQuerySchema, 'query'), listRentalProposals);
  router.get('/rental-proposals/:proposalId', getRentalProposal);
  router.patch('/rental-proposals/:proposalId', validate(updateRentalProposalSchema), updateRentalProposal);
  router.post('/rental-proposals/:proposalId/action', validate(rentalProposalActionSchema), actionRentalProposal);

  // ============================================================================
  // Financial - Invoices
  // ============================================================================
  router.post('/invoices', validate(createInvoiceSchema), createInvoice);
  router.get('/invoices', validate(invoiceQuerySchema, 'query'), listInvoices);
  router.get('/invoices/:invoiceId', getInvoice);

  // ============================================================================
  // Financial - Payments
  // ============================================================================
  router.post('/payments', validate(recordPaymentSchema), recordPayment);

  // ============================================================================
  // Financial - Rent Ledger
  // ============================================================================
  router.get('/rent-ledger', validate(invoiceQuerySchema, 'query'), listRentLedger);

  // ============================================================================
  // Maintenance / Issues
  // ============================================================================
  router.post('/issues', validate(reportIssueSchema), reportIssue);
  router.get('/issues', validate(issueQuerySchema, 'query'), listIssues);
  router.get('/issues/:issueId', getIssue);
  router.patch('/issues/:issueId', validate(updateIssueSchema), updateIssue);

  // ============================================================================
  // Lease / Rental Agreements
  // ============================================================================
  router.post('/rental-agreements', validate(createRentalAgreementSchema), createRentalAgreement);
  router.get('/rental-agreements', validate(rentalProposalQuerySchema, 'query'), listRentalAgreements);
  router.get('/rental-agreements/:agreementId', getRentalAgreement);
  router.patch('/rental-agreements/:agreementId', validate(updateRentalAgreementSchema), updateRentalAgreement);

  // ============================================================================
  // Lease Documents
  // ============================================================================
  router.post('/lease-documents', validate(uploadLeaseDocumentSchema), uploadLeaseDocument);
  router.get('/lease-documents', validate(rentalProposalQuerySchema, 'query'), listLeaseDocuments);

  // ============================================================================
  // Inspections
  // ============================================================================
  router.post('/move-in-inspections', validate(createMoveInInspectionSchema), createMoveInInspection);
  router.post('/move-out-inspections', validate(createMoveOutInspectionSchema), createMoveOutInspection);
  router.post('/inspection-items', validate(createInspectionItemSchema), createInspectionItem);
  router.get('/inspection-items/:inspectionId', getInspectionItems);

  // ============================================================================
  // Dashboard
  // ============================================================================
  router.get('/dashboard', validate(dashboardQuerySchema, 'query'), getDashboardStats);
  router.get('/dashboard/extended', validate(dashboardQuerySchema, 'query'), getExtendedDashboardStats);

  return router;
}
