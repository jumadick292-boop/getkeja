import * as repo from './profile.repository.js';
import { z } from 'zod';
import type {
  CreateSpecializedProfileInput,
  LaundryServicesInput,
  OrganizationProfileInput,
  OrganizationReviewInput,
  PersonalProfileInput,
  ProfileReviewInput,
  ProviderExtensionInput,
  SavedLocationInput,
  ServiceAreaInput,
  UpdateServiceAreaInput,
  UpdateSpecializedProfileInput,
} from './profile.schema.js';
import { profileImageUploadSchema } from './profile.schema.js';
import { ForbiddenError } from '../../shared/errors.js';
import { uploadProfileImage, type UploadedProfileImage } from './profile-image-upload.service.js';

export const personal = {
  get: (userId: string) => repo.getOrCreatePersonalProfile(userId),
  update: (userId: string, data: PersonalProfileInput) => repo.updatePersonalProfile(userId, data),
};

export const uploads = {
  image: async (
    userId: string,
    input: z.infer<typeof profileImageUploadSchema>,
    file: { buffer: Buffer; mimetype: string; size: number },
  ): Promise<UploadedProfileImage> => {
    if (!(await repo.canUploadProfileImage(userId, input))) {
      throw new ForbiddenError('You cannot upload an image for this profile');
    }
    return uploadProfileImage(userId, input, file);
  },
};

export const specialized = {
  list: (userId: string) => repo.listSpecializedProfiles(userId),
  create: (userId: string, data: CreateSpecializedProfileInput) =>
    repo.createSpecializedProfile(userId, data),
  get: (profileId: string, userId: string) => repo.getSpecializedProfile(profileId, userId),
  update: (profileId: string, userId: string, data: UpdateSpecializedProfileInput) =>
    repo.updateSpecializedProfile(profileId, userId, data),
  submit: (profileId: string, userId: string) => repo.submitProfile(profileId, userId),
  providerExtension: {
    get: (profileId: string, userId: string) => repo.getProviderExtension(profileId, userId),
    upsert: (profileId: string, userId: string, data: ProviderExtensionInput) =>
      repo.upsertProviderExtension(profileId, userId, data),
  },
  laundryServices: {
    get: (extensionId: string, userId: string) => repo.getLaundryServices(extensionId, userId),
    upsert: (extensionId: string, userId: string, data: LaundryServicesInput) =>
      repo.upsertLaundryServices(extensionId, userId, data),
  },
  completion: {
    get: (profileId: string, userId: string) => repo.getCompletionMetadata(profileId, userId),
  },
};

export const locations = {
  save: (userId: string, data: SavedLocationInput) => repo.saveLocation(userId, data),
  list: (userId: string, profileId?: string) => repo.getLocations(userId, profileId),
  delete: (userId: string, locationId: string) => repo.deleteLocation(userId, locationId),
};

export const serviceAreas = {
  add: (userId: string, data: ServiceAreaInput) => repo.addServiceArea(userId, data),
  list: (profileId: string, userId: string) => repo.listServiceAreas(profileId, userId),
  update: (areaId: string, userId: string, data: UpdateServiceAreaInput) =>
    repo.updateServiceArea(areaId, userId, data),
  delete: (areaId: string, userId: string) => repo.deleteServiceArea(areaId, userId),
};

export const verification = {
  list: (profileId: string, userId: string) =>
    repo.listVerificationRecords(profileId, userId),
  queue: () => repo.listProfilesForReview(),
  review: (profileId: string, reviewerId: string, data: ProfileReviewInput) =>
    repo.reviewProfile(profileId, reviewerId, data),
};

export const organizations = {
  get: (organizationId: string, userId: string) =>
    repo.getOrganizationProfile(organizationId, userId),
  update: (organizationId: string, userId: string, data: OrganizationProfileInput) =>
    repo.updateOrganizationProfile(organizationId, userId, data),
  submit: (organizationId: string, userId: string) =>
    repo.submitOrganizationForReview(organizationId, userId),
  verificationRecords: (organizationId: string, userId: string) =>
    repo.listOrganizationVerificationRecords(organizationId, userId),
  verificationQueue: () => repo.listOrganizationsForReview(),
  review: (organizationId: string, reviewerId: string, data: OrganizationReviewInput) =>
    repo.reviewOrganization(organizationId, reviewerId, data),
};
