// Provider routes — provider-facing API under /api/v1/provider.
import { Router } from 'express';
import { requireAuth } from '../auth/auth.middleware.js';
import { validate } from '../../middleware/validate.js';
import {
  providerInboxQuerySchema,
  providerRequestIdParamsSchema,
  providerRespondSchema,
  providerDiscoveryQuerySchema,
} from './provider.schemas.js';
import {
  catalogueQuerySchema,
  catalogueDomainParamsSchema,
  offeringListQuerySchema,
  offeringIdParamsSchema,
  createOfferingSchema,
  updateOfferingSchema,
  offeringCapabilitiesSchema,
  offeringPricingSchema,
  locationListQuerySchema,
  locationIdParamsSchema,
  createLocationSchema,
  updateLocationSchema,
  serviceAreaListQuerySchema,
  serviceAreaIdParamsSchema,
  createServiceAreaSchema,
  updateServiceAreaSchema,
  availabilityQuerySchema,
  operatingHoursReplaceSchema,
  exceptionIdParamsSchema,
  createExceptionSchema,
  updateExceptionSchema,
} from './provider-catalogue.schemas.js';
import {
  getCatalogue,
  getCatalogueByDomain,
  listOfferings,
  createOffering,
  getOffering,
  updateOffering,
  activateOffering,
  pauseOffering,
  archiveOffering,
  getCapabilities,
  replaceCapabilities,
  getPricing,
  setPricing,
  listLocations,
  createLocation,
  updateLocation,
  deleteLocation,
  setPrimaryLocation,
  listServiceAreas,
  createServiceArea,
  updateServiceArea,
  deleteServiceArea,
  getAvailability,
  replaceAvailability,
  listExceptions,
  createException,
  updateException,
  deleteException,
} from './provider-catalogue.controller.js';
import {
  createSpecializedProfileSchema,
  updateSpecializedProfileSchema,
  profileIdParamsSchema,
} from '../profile/profile.schema.js';
import {
  createOrganisationSchema,
  updateOrganisationSchema,
  createInvitationSchema,
  updateMemberSchema,
} from '../auth/auth.schema.js';
import {
  getProviderDashboard,
  getProviderRequests,
  getProviderRequestDetail,
  respondToProviderRequest,
  discoverProviders,
  listMyProviderProfiles,
  createMyProviderProfile,
  getMyProviderProfile,
  updateMyProviderProfile,
  submitMyProviderProfile,
  listMyOrganizations,
  createMyOrganization,
  getMyOrganization,
  updateMyOrganization,
  setMyOrganizationActive,
  listOrgStaff,
  inviteOrgStaff,
  listOrgInvitations,
  acceptOrgInvitation,
  declineOrgInvitation,
  revokeOrgInvitation,
  updateOrgStaff,
  removeOrgStaff,
} from './provider.controller.js';

export function createProviderRouter(): Router {
  const router = Router();

  // All provider endpoints require authentication. Authorization is
  // resource-scoped inside the service layer (approved profile / assignment),
  // not role-name based.
  router.use(requireAuth);

  router.get('/dashboard', getProviderDashboard);

  router.get(
    '/requests',
    validate(providerInboxQuerySchema, 'query'),
    getProviderRequests,
  );

  router.get(
    '/requests/:requestId',
    validate(providerRequestIdParamsSchema, 'params'),
    getProviderRequestDetail,
  );

  router.post(
    '/requests/:requestId/respond',
    validate(providerRequestIdParamsSchema, 'params'),
    validate(providerRespondSchema, 'body'),
    respondToProviderRequest,
  );

  router.get(
    '/discovery',
    validate(providerDiscoveryQuerySchema, 'query'),
    discoverProviders,
  );

  // Provider profiles (provider-scoped surface over the profile module).
  router.get('/profile', listMyProviderProfiles);
  router.post('/profile', validate(createSpecializedProfileSchema, 'body'), createMyProviderProfile);
  router.get('/profiles', listMyProviderProfiles);
  router.get('/profiles/:profileId', validate(profileIdParamsSchema, 'params'), getMyProviderProfile);
  router.patch('/profiles/:profileId', validate(profileIdParamsSchema, 'params'), validate(updateSpecializedProfileSchema, 'body'), updateMyProviderProfile);
  router.post('/profiles/:profileId/submit', validate(profileIdParamsSchema, 'params'), submitMyProviderProfile);

  // Provider organizations.
  router.get('/organizations', listMyOrganizations);
  router.post('/organizations', validate(createOrganisationSchema, 'body'), createMyOrganization);
  router.get('/organizations/:organizationId', getMyOrganization);
  router.patch('/organizations/:organizationId', validate(updateOrganisationSchema, 'body'), updateMyOrganization);
  router.post('/organizations/:organizationId/deactivate', setMyOrganizationActive);
  router.post('/organizations/:organizationId/activate', setMyOrganizationActive);

  // Organization staff & invitations.
  router.get('/organizations/:organizationId/staff', listOrgStaff);
  router.patch('/organizations/:organizationId/staff/:memberId', validate(updateMemberSchema, 'body'), updateOrgStaff);
  router.delete('/organizations/:organizationId/staff/:memberId', removeOrgStaff);
  router.get('/organizations/:organizationId/invitations', listOrgInvitations);
  router.post('/organizations/:organizationId/invitations', validate(createInvitationSchema, 'body'), inviteOrgStaff);
  router.delete('/organizations/:organizationId/invitations/:invitationId', revokeOrgInvitation);
  router.post('/invitations/accept', acceptOrgInvitation);
  router.post('/invitations/decline', declineOrgInvitation);

  // ---- Service catalogue (Task 13.4) ----
  router.get('/services/catalogue', validate(catalogueQuerySchema, 'query'), getCatalogue);
  router.get('/services/catalogue/:serviceType', validate(catalogueDomainParamsSchema, 'params'), getCatalogueByDomain);

  router.get('/services', validate(offeringListQuerySchema, 'query'), listOfferings);
  router.post('/services', validate(createOfferingSchema, 'body'), createOffering);
  router.get('/services/:serviceId', validate(offeringIdParamsSchema, 'params'), getOffering);
  router.patch('/services/:serviceId', validate(offeringIdParamsSchema, 'params'), validate(updateOfferingSchema, 'body'), updateOffering);
  router.post('/services/:serviceId/activate', validate(offeringIdParamsSchema, 'params'), activateOffering);
  router.post('/services/:serviceId/pause', validate(offeringIdParamsSchema, 'params'), pauseOffering);
  router.post('/services/:serviceId/archive', validate(offeringIdParamsSchema, 'params'), archiveOffering);

  router.get('/services/:serviceId/capabilities', validate(offeringIdParamsSchema, 'params'), getCapabilities);
  router.patch('/services/:serviceId/capabilities', validate(offeringIdParamsSchema, 'params'), validate(offeringCapabilitiesSchema, 'body'), replaceCapabilities);
  router.get('/services/:serviceId/pricing', validate(offeringIdParamsSchema, 'params'), getPricing);
  router.put('/services/:serviceId/pricing', validate(offeringIdParamsSchema, 'params'), validate(offeringPricingSchema, 'body'), setPricing);

  // ---- Locations ----
  router.get('/locations', validate(locationListQuerySchema, 'query'), listLocations);
  router.post('/locations', validate(createLocationSchema, 'body'), createLocation);
  router.patch('/locations/:locationId', validate(locationIdParamsSchema, 'params'), validate(updateLocationSchema, 'body'), updateLocation);
  router.delete('/locations/:locationId', validate(locationIdParamsSchema, 'params'), deleteLocation);
  router.post('/locations/:locationId/set-primary', validate(locationIdParamsSchema, 'params'), setPrimaryLocation);

  // ---- Service areas ----
  router.get('/service-areas', validate(serviceAreaListQuerySchema, 'query'), listServiceAreas);
  router.post('/service-areas', validate(createServiceAreaSchema, 'body'), createServiceArea);
  router.patch('/service-areas/:areaId', validate(serviceAreaIdParamsSchema, 'params'), validate(updateServiceAreaSchema, 'body'), updateServiceArea);
  router.delete('/service-areas/:areaId', validate(serviceAreaIdParamsSchema, 'params'), deleteServiceArea);

  // ---- Operating hours & availability ----
  router.get('/availability', validate(availabilityQuerySchema, 'query'), getAvailability);
  router.put('/availability', validate(operatingHoursReplaceSchema, 'body'), replaceAvailability);
  router.get('/availability/exceptions', listExceptions);
  router.post('/availability/exceptions', validate(createExceptionSchema, 'body'), createException);
  router.patch('/availability/exceptions/:exceptionId', validate(exceptionIdParamsSchema, 'params'), validate(updateExceptionSchema, 'body'), updateException);
  router.delete('/availability/exceptions/:exceptionId', validate(exceptionIdParamsSchema, 'params'), deleteException);

  return router;
}