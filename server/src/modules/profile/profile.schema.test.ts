import { describe, expect, it } from 'vitest';
import {
  createSpecializedProfileSchema,
  organizationProfileSchema,
  placeIdParamsSchema,
  placeSearchQuerySchema,
  profileCategorySchema,
  profileImageUploadSchema,
  profileReviewSchema,
  saveLocationSchema,
  serviceAreaSchema,
} from './profile.schema.js';

describe('profile schemas', () => {
  it('supports all blueprint categories and the laundry provider category', () => {
    expect(profileCategorySchema.options).toContain('laundry_service_provider');
    expect(profileCategorySchema.options).toHaveLength(10);
  });

  it('rejects profile fields that could grant roles or property access', () => {
    const result = createSpecializedProfileSchema.safeParse({
      profileCategory: 'landlord',
      role: 'platform_admin',
      propertyId: '00000000-0000-4000-8000-000000000001',
    });
    expect(result.success).toBe(false);
  });

  it('validates image upload kinds and scope identifiers', () => {
    expect(profileImageUploadSchema.safeParse({
      kind: 'personal_photo',
    }).success).toBe(true);
    expect(profileImageUploadSchema.safeParse({
      kind: 'business_logo',
      profileId: '00000000-0000-4000-8000-000000000001',
    }).success).toBe(true);
    expect(profileImageUploadSchema.safeParse({
      kind: 'organization_logo',
      organizationId: 'not-an-id',
    }).success).toBe(false);
    expect(profileImageUploadSchema.safeParse({
      kind: 'organization_logo',
      organizationId: '00000000-0000-4000-8000-000000000001',
      profileId: '00000000-0000-4000-8000-000000000002',
    }).success).toBe(false);
  });

  it('requires membership-bound IDs to be valid UUIDs', () => {
    const result = createSpecializedProfileSchema.safeParse({
      profileCategory: 'agency',
      organisationId: 'not-an-id',
    });
    expect(result.success).toBe(false);
  });

  it('validates coordinates and keeps personal residential locations unlinked', () => {
    expect(saveLocationSchema.safeParse({
      locationType: 'personal_residential',
      latitude: 0.1,
      longitude: 37.2,
      locationSource: 'manual_map_pin',
    }).success).toBe(true);

    expect(saveLocationSchema.safeParse({
      locationType: 'personal_residential',
      specializedProfileId: '00000000-0000-4000-8000-000000000001',
      latitude: 0.1,
      longitude: 37.2,
    }).success).toBe(false);

    expect(saveLocationSchema.safeParse({
      locationType: 'provider_operating',
      specializedProfileId: '00000000-0000-4000-8000-000000000001',
      latitude: 91,
      longitude: 37.2,
    }).success).toBe(false);
  });

  it('requires service-area coordinates to be supplied together', () => {
    expect(serviceAreaSchema.safeParse({
      profileId: '00000000-0000-4000-8000-000000000001',
      latitude: -1.2,
      longitude: 36.8,
      radiusKm: 20,
    }).success).toBe(true);
    expect(serviceAreaSchema.safeParse({
      profileId: '00000000-0000-4000-8000-000000000001',
      latitude: -1.2,
    }).success).toBe(false);
  });

  it('requires valid organization office coordinates and rejection reasons', () => {
    expect(organizationProfileSchema.safeParse({
      latitude: 10,
    }).success).toBe(false);
    expect(profileReviewSchema.safeParse({
      decision: 'rejected',
    }).success).toBe(false);
  });

  it('validates place search terms and Google place IDs', () => {
    expect(placeSearchQuerySchema.safeParse({ input: 'Nairobi' }).success).toBe(true);
    expect(placeSearchQuerySchema.safeParse({ input: ' ' }).success).toBe(false);
    expect(placeIdParamsSchema.safeParse({ placeId: 'ChIJ123' }).success).toBe(true);
  });
});
