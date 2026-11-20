import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { requireAuth } from '../auth/auth.middleware.js';
import { requireSystemRole } from '../auth/authorization.middleware.js';
import { createRateLimiter } from '../../middleware/rate-limit.js';
import * as controller from './profile.controller.js';
import { receiveProfileImage } from './profile-image-upload.middleware.js';
import {
  createPersonalProfileSchema,
  createSpecializedProfileSchema,
  laundryServicesSchema,
  organizationReviewSchema,
  organizationIdParamsSchema,
  organizationProfileSchema,
  profileIdParamsSchema,
  profileIdQuerySchema,
  placeIdParamsSchema,
  placeSearchQuerySchema,
  profileImageUploadSchema,
  profileReviewSchema,
  providerExtensionIdParamsSchema,
  providerExtensionSchema,
  saveLocationSchema,
  serviceAreaSchema,
  serviceAreaIdParamsSchema,
  serviceAreasProfileParamsSchema,
  updateServiceAreaSchema,
  updateSpecializedProfileSchema,
  verificationDocumentIdParamsSchema,
  verificationDocumentSchema,
} from './profile.schema.js';
import { receiveVerificationDocument } from './verification-document-upload.middleware.js';

const router = Router();
router.use(requireAuth);
const placesRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 30,
  keyPrefix: 'profile:places',
  identifierField: 'userId',
});

router.get('/profile/personal', controller.getPersonal);
router.patch('/profile/personal', validate(createPersonalProfileSchema), controller.updatePersonal);
router.post(
  '/profile/uploads/image',
  createRateLimiter({
    windowMs: 60 * 60 * 1000,
    max: 20,
    keyPrefix: 'profile:image-upload',
    identifierField: 'userId',
  }),
  receiveProfileImage,
  validate(profileImageUploadSchema),
  controller.uploadImage,
);

router.get('/profiles', controller.listSpecialized);
router.post('/profiles', validate(createSpecializedProfileSchema), controller.createSpecialized);
router.get('/profiles/:id', validate(profileIdParamsSchema, 'params'), controller.getSpecialized);
router.patch(
  '/profiles/:id',
  validate(profileIdParamsSchema, 'params'),
  validate(updateSpecializedProfileSchema),
  controller.updateSpecialized,
);
router.post('/profiles/:id/submit', validate(profileIdParamsSchema, 'params'), controller.submitSpecialized);
router.get('/profiles/:id/completion', validate(profileIdParamsSchema, 'params'), controller.getCompletion);
router.put('/profiles/:id/completion', validate(profileIdParamsSchema, 'params'), controller.getCompletion);
router.get(
  '/profiles/:id/verification-records',
  validate(profileIdParamsSchema, 'params'),
  controller.listVerification,
);
router.get('/profiles/:id/verification-documents', validate(profileIdParamsSchema, 'params'), controller.listProfileVerificationDocuments);
router.post(
  '/profiles/:id/verification-documents',
  validate(profileIdParamsSchema, 'params'), receiveVerificationDocument,
  validate(verificationDocumentSchema), controller.uploadProfileVerificationDocument,
);
router.get(
  '/organizations/:organizationId/profile/verification-documents',
  validate(organizationIdParamsSchema, 'params'), controller.listOrganizationVerificationDocuments,
);
router.post(
  '/organizations/:organizationId/profile/verification-documents',
  validate(organizationIdParamsSchema, 'params'), receiveVerificationDocument,
  validate(verificationDocumentSchema), controller.uploadOrganizationVerificationDocument,
);
router.get(
  '/verification-documents/:documentId/download-url',
  validate(verificationDocumentIdParamsSchema, 'params'), controller.verificationDocumentDownloadUrl,
);

router.post('/locations', validate(saveLocationSchema), controller.saveLocation);
router.get('/locations', validate(profileIdQuerySchema, 'query'), controller.listLocations);
router.get('/places/autocomplete', placesRateLimiter, validate(placeSearchQuerySchema, 'query'), controller.searchPlaces);
router.get('/places/:placeId', placesRateLimiter, validate(placeIdParamsSchema, 'params'), controller.getPlace);

router.post('/service-areas', validate(serviceAreaSchema), controller.addServiceArea);
router.get(
  '/service-areas/:profileId',
  validate(serviceAreasProfileParamsSchema, 'params'),
  controller.listServiceAreas,
);
router.patch(
  '/service-areas/:areaId',
  validate(serviceAreaIdParamsSchema, 'params'),
  validate(updateServiceAreaSchema),
  controller.updateServiceArea,
);
router.delete(
  '/service-areas/:areaId',
  validate(serviceAreaIdParamsSchema, 'params'),
  controller.deleteServiceArea,
);

router.get(
  '/profiles/:id/provider-extension',
  validate(profileIdParamsSchema, 'params'),
  controller.getProviderExtension,
);
router.put(
  '/profiles/:id/provider-extension',
  validate(profileIdParamsSchema, 'params'),
  validate(providerExtensionSchema),
  controller.upsertProviderExtension,
);
router.get(
  '/provider-extensions/:providerProfileId/laundry-services',
  validate(providerExtensionIdParamsSchema, 'params'),
  controller.getLaundryServices,
);
router.put(
  '/provider-extensions/:providerProfileId/laundry-services',
  validate(providerExtensionIdParamsSchema, 'params'),
  validate(laundryServicesSchema),
  controller.upsertLaundryServices,
);

router.get(
  '/organizations/:organizationId/profile',
  validate(organizationIdParamsSchema, 'params'),
  controller.getOrganizationProfile,
);
router.patch(
  '/organizations/:organizationId/profile',
  validate(organizationIdParamsSchema, 'params'),
  validate(organizationProfileSchema),
  controller.updateOrganizationProfile,
);
router.post(
  '/organizations/:organizationId/profile/submit',
  validate(organizationIdParamsSchema, 'params'),
  controller.submitOrganizationProfile,
);
router.get(
  '/organizations/:organizationId/profile/verification-records',
  validate(organizationIdParamsSchema, 'params'),
  controller.organizationVerificationRecords,
);

router.get('/admin/verification-queue', requireSystemRole, controller.profileReviewQueue);
router.get(
  '/admin/profiles/:id/verification-documents', requireSystemRole,
  validate(profileIdParamsSchema, 'params'), controller.adminListProfileVerificationDocuments,
);
router.get(
  '/admin/verification-documents/:documentId/download-url', requireSystemRole,
  validate(verificationDocumentIdParamsSchema, 'params'), controller.adminVerificationDocumentDownloadUrl,
);
router.post(
  '/admin/profiles/:id/review',
  requireSystemRole,
  validate(profileIdParamsSchema, 'params'),
  validate(profileReviewSchema),
  controller.reviewProfile,
);
router.get(
  '/admin/organization-verification-queue',
  requireSystemRole,
  controller.organizationReviewQueue,
);
router.get(
  '/admin/organizations/:organizationId/verification-documents', requireSystemRole,
  validate(organizationIdParamsSchema, 'params'), controller.adminListOrganizationVerificationDocuments,
);
router.post(
  '/admin/organizations/:organizationId/review',
  requireSystemRole,
  validate(organizationIdParamsSchema, 'params'),
  validate(organizationReviewSchema),
  controller.reviewOrganization,
);

export function createProfileRouter() {
  return router;
}
