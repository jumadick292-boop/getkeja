import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import { requireAuth } from '../auth/auth.middleware.js';
import * as controller from './house-seeker.controller.js';import {
  searchQuerySchema,
  mapBoundsQuerySchema,
  listingIdParamSchema,
  saveListingSchema,
  savedListingsQuerySchema,
  createSavedSearchSchema,
  updateSavedSearchSchema,
  savedSearchIdParamSchema,
  comparisonAddSchema,
  comparisonItemParamSchema,
  comparisonQuerySchema,
  createSeekerEnquirySchema,
  enquiryIdParamSchema,
  seekerEnquiryQuerySchema,
  createListingReportSchema,
  updatePreferencesSchema,
  createSeekerSiteVisitSchema,
  siteVisitIdParamSchema,
  rescheduleVisitSchema,
  cancelVisitSchema,
  propertyIdParamSchema,
  seekerSiteVisitQuerySchema,
  availabilityQuerySchema,
  startConversationSchema,
  conversationIdParamSchema,
  seekerMessagesQuerySchema,
  sendMessageSchema,
  createSeekerApplicationSchema,
  applicationIdParamSchema,
  seekerApplicationQuerySchema,
  proposalIdParamSchema,
  respondToProposalSchema,
  seekerProposalQuerySchema,
  relatedListingsQuerySchema,
  runSavedSearchQuerySchema,
  seekerJourneyQuerySchema,
} from './house-seeker.schema.js';

const router = Router();
router.use(requireAuth);

const searchLimiter = createRateLimiter({
  windowMs: 60_000,
  max: 90,
  keyPrefix: 'house-seeker:search',
  identifierField: 'userId',
});

const enquiryLimiter = createRateLimiter({
  windowMs: 60_000,
  max: 10,
  keyPrefix: 'house-seeker:enquiry',
  identifierField: 'userId',
});

const reportLimiter = createRateLimiter({
  windowMs: 60_000,
  max: 10,
  keyPrefix: 'house-seeker:report',
  identifierField: 'userId',
});

// ============================================================================
// Discovery
// ============================================================================
router.get('/listings', searchLimiter, validate(searchQuerySchema, 'query'), controller.search);
router.get('/listings/featured', controller.featured);
router.get('/listings/map', validate(mapBoundsQuerySchema, 'query'), controller.mapResults);
router.get('/listings/filters', controller.filters);
router.get('/listings/:listingId', validate(listingIdParamSchema, 'params'), controller.getListing);
router.get('/listings/:listingId/related', validate(listingIdParamSchema, 'params'), validate(relatedListingsQuerySchema, 'query'), controller.getRelatedListings);

// ============================================================================
// Saved homes
// ============================================================================
router.post('/saved-listings', validate(saveListingSchema), controller.save);
router.get('/saved-listings', validate(savedListingsQuerySchema, 'query'), controller.listSaved);
router.delete('/saved-listings/:listingId', validate(listingIdParamSchema, 'params'), controller.unsave);

// ============================================================================
// Saved searches
// ============================================================================
router.post('/saved-searches', validate(createSavedSearchSchema), controller.createSearch);
router.get('/saved-searches', controller.listSearches);
router.patch('/saved-searches/:searchId', validate(savedSearchIdParamSchema, 'params'), validate(updateSavedSearchSchema), controller.updateSearch);
router.delete('/saved-searches/:searchId', validate(savedSearchIdParamSchema, 'params'), controller.removeSearch);
router.get('/saved-searches/:searchId/run', validate(savedSearchIdParamSchema, 'params'), validate(runSavedSearchQuerySchema, 'query'), controller.runSavedSearch);

// ============================================================================
// Property comparison
// ============================================================================
router.get('/comparison', validate(comparisonQuerySchema, 'query'), controller.getComparison);
router.post('/comparison', validate(comparisonAddSchema), controller.addToComparison);
router.delete('/comparison/:listingId', validate(comparisonItemParamSchema, 'params'), controller.removeFromComparison);
router.delete('/comparison', controller.clearComparison);

// ============================================================================
// Enquiries
// ============================================================================
router.post('/enquiries', enquiryLimiter, validate(createSeekerEnquirySchema), controller.submitEnquiry);
router.get('/enquiries', validate(seekerEnquiryQuerySchema, 'query'), controller.listEnquiries);
router.get('/enquiries/:enquiryId', validate(enquiryIdParamSchema, 'params'), controller.getEnquiry);
router.post('/enquiries/:enquiryId/withdraw', validate(enquiryIdParamSchema, 'params'), controller.withdraw);

// ============================================================================
// Preferences
// ============================================================================
router.get('/preferences', controller.getPreferences);
router.put('/preferences', validate(updatePreferencesSchema), controller.updatePreferences);

// ============================================================================
// Listing reports
// ============================================================================
router.post('/listing-reports', reportLimiter, validate(createListingReportSchema), controller.reportListing);

// ============================================================================
// Site visits (house seeker side)
// ============================================================================
router.post('/site-visits', validate(createSeekerSiteVisitSchema), controller.requestSiteVisit);
router.get('/site-visits', validate(seekerSiteVisitQuerySchema, 'query'), controller.listSiteVisits);
router.get('/site-visits/:visitId', validate(siteVisitIdParamSchema, 'params'), controller.getSiteVisit);
router.get('/listings/:listingId/availability', validate(listingIdParamSchema, 'params'), validate(availabilityQuerySchema, 'query'), controller.getListingAvailability);
router.post('/site-visits/:visitId/cancel', validate(siteVisitIdParamSchema, 'params'), validate(cancelVisitSchema), controller.cancelSiteVisit);
router.post('/site-visits/:visitId/reschedule', validate(siteVisitIdParamSchema, 'params'), validate(rescheduleVisitSchema), controller.rescheduleSiteVisit);

// ============================================================================
// Conversations & messages (house seeker side)
// ============================================================================
router.post('/conversations', validate(startConversationSchema), controller.startConversation);
router.get('/conversations', controller.listConversations);
router.get('/conversations/:conversationId', validate(conversationIdParamSchema, 'params'), controller.getConversation);
router.get('/conversations/:conversationId/messages', validate(conversationIdParamSchema, 'params'), validate(seekerMessagesQuerySchema, 'query'), controller.listMessages);
router.post('/conversations/:conversationId/read', validate(conversationIdParamSchema, 'params'), controller.markRead);
router.post('/messages', validate(sendMessageSchema), controller.sendMessage);

// ============================================================================
// Rental applications (house seeker side)
// ============================================================================
router.post('/applications', validate(createSeekerApplicationSchema), controller.submitApplication);
router.get('/applications', validate(seekerApplicationQuerySchema, 'query'), controller.listApplications);
router.get('/applications/:applicationId', validate(applicationIdParamSchema, 'params'), controller.getApplication);
router.post('/applications/:applicationId/withdraw', validate(applicationIdParamSchema, 'params'), controller.withdrawApplication);

// ============================================================================
// Rental proposals (house seeker responses)
// ============================================================================
router.get('/proposals', validate(seekerProposalQuerySchema, 'query'), controller.listProposals);
router.get('/proposals/:proposalId', validate(proposalIdParamSchema, 'params'), controller.getProposal);
router.post('/proposals/:proposalId/respond', validate(proposalIdParamSchema, 'params'), validate(respondToProposalSchema), controller.respondToProposal);

// ============================================================================
// Rental journey
// ============================================================================
router.get('/journey', validate(seekerJourneyQuerySchema, 'query'), controller.getJourney);

export function createHouseSeekerRouter() {
  return router;
}