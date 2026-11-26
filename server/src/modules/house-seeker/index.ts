// House Seeker module barrel export.
// Public surface: route factory and validation/schema types.
export { createHouseSeekerRouter } from './house-seeker.routes.js';

export type {
  SearchQuery,
  MapBoundsQuery,
  ListingIdParam,
  SaveListing,
  CreateSavedSearch,
  UpdateSavedSearch,
  CreateSeekerEnquiry,
  UpdatePreferences,
  CreateListingReport,
  CreateSeekerSiteVisit,
  StartConversation,
  SendMessage,
  CreateSeekerApplication,
  RespondToProposal,
} from './house-seeker.schema.js';

export const houseSeekerRoutePath = '/api/v1/house-seeker';
