import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  clientQuery: vi.fn(),
  clientRelease: vi.fn(),
  poolConnect: vi.fn(),
  poolQuery: vi.fn(),
}));

vi.mock('../../db/pool.js', () => ({
  pool: {
    connect: mocks.poolConnect,
    query: mocks.poolQuery,
  },
}));

import {
  canUploadProfileImage,
  canUploadVerificationDocument,
  createSpecializedProfile,
  getVerificationDocumentForAccess,
  saveLocation,
  updateSpecializedProfile,
} from './profile.repository.js';

const userId = '00000000-0000-4000-8000-000000000001';
const profileId = '00000000-0000-4000-8000-000000000002';
const organizationId = '00000000-0000-4000-8000-000000000003';

describe('profile repository authorization', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.clientQuery.mockResolvedValue({ rows: [], rowCount: 0 });
    mocks.poolConnect.mockResolvedValue({
      query: mocks.clientQuery,
      release: mocks.clientRelease,
    });
  });

  it('does not update a specialized profile without ownership or organization-admin membership', async () => {
    const result = await updateSpecializedProfile(profileId, userId, {
      description: 'Attempted unauthorized update',
    });

    expect(result).toBeNull();
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('om.role IN (\'owner\', \'admin\')'),
      [profileId, userId],
    );
    expect(mocks.clientQuery).not.toHaveBeenCalledWith(
      expect.stringContaining('UPDATE specialized_profiles'),
      expect.anything(),
    );
    expect(mocks.clientRelease).toHaveBeenCalledOnce();
  });

  it('does not save a location against another users profile', async () => {
    const result = await saveLocation(userId, {
      locationType: 'provider_operating',
      specializedProfileId: profileId,
      latitude: -1.2,
      longitude: 36.8,
      locationSource: 'manual_map_pin',
    });

    expect(result).toBeNull();
    expect(mocks.clientQuery).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO saved_locations'),
      expect.anything(),
    );
  });

  it('allows organization logo uploads only for active owners and admins', async () => {
    mocks.poolQuery.mockResolvedValueOnce({ rows: [], rowCount: 0 });
    await expect(canUploadProfileImage(userId, {
      kind: 'organization_logo',
      organizationId,
    })).resolves.toBe(false);

    expect(mocks.poolQuery).toHaveBeenCalledWith(
      expect.stringContaining("om.role IN ('owner', 'admin')"),
      [organizationId, userId],
    );
  });

  it('allows specialized image uploads only for profile owners or organization admins', async () => {
    mocks.poolQuery.mockResolvedValueOnce({ rows: [], rowCount: 0 });
    await expect(canUploadProfileImage(userId, {
      kind: 'profile_photo',
      profileId,
    })).resolves.toBe(false);
  });

  it('denies verification document uploads to users without profile or organization authority', async () => {
    mocks.poolQuery.mockResolvedValueOnce({ rows: [], rowCount: 0 });
    await expect(canUploadVerificationDocument(userId, { profileId })).resolves.toBe(false);
    expect(mocks.poolQuery).toHaveBeenCalledWith(
      expect.stringContaining("sp.verification_status <> 'suspended'"),
      [profileId, userId],
    );
  });

  it('records denied attempts to retrieve a private verification document', async () => {
    mocks.clientQuery
      .mockResolvedValueOnce({ rows: [], rowCount: null })
      .mockResolvedValueOnce({ rows: [{ id: profileId, profileOwnerId: 'another-user', status: 'submitted' }], rowCount: 1 })
      .mockResolvedValueOnce({ rows: [], rowCount: 0 })
      .mockResolvedValue({ rows: [], rowCount: 1 });
    await expect(getVerificationDocumentForAccess(profileId, userId, false)).resolves.toBe(false);
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('access_granted'),
      [profileId, userId, false],
    );
  });

  it('requires active, authorized agency membership before attaching an agency profile', async () => {
    mocks.clientQuery.mockImplementation(async (sql: string) => {
      if (sql.includes('FROM organisations o')) return { rows: [{}], rowCount: 1 };
      return { rows: [], rowCount: 0 };
    });
    const result = await createSpecializedProfile(userId, {
      profileCategory: 'agency',
      organisationId: organizationId,
    });

    expect(result).toBeNull();
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('JOIN organisation_members'),
      [organizationId, userId],
    );
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('WHERE user_id = $1 AND organisation_id = $2'),
      [userId, organizationId],
    );
    expect(mocks.clientQuery).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO specialized_profiles'),
      expect.anything(),
    );
  });

  it('rejects profile creation when the matching role is not assigned', async () => {
    await expect(createSpecializedProfile(userId, {
      profileCategory: 'landlord',
    })).rejects.toThrow('assigned role');
    expect(mocks.clientQuery).toHaveBeenCalledWith(
      expect.stringContaining('FROM user_roles'),
      [userId, ['landlord'], null],
    );
    expect(mocks.clientQuery).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO specialized_profiles'),
      expect.anything(),
    );
  });
});
