import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  clientQuery: vi.fn(),
  clientRelease: vi.fn(),
  poolConnect: vi.fn(),
  findUserByEmail: vi.fn(),
  findLoginIdentity: vi.fn(),
  getRoleById: vi.fn(),
  findUserWithRolesById: vi.fn(),
  sendVerificationEmail: vi.fn(),
}));

vi.mock('../../db/pool.js', () => ({
  pool: {
    connect: mocks.poolConnect,
  },
}));

vi.mock('./auth.repository.js', () => ({
  findUserByEmail: mocks.findUserByEmail,
  findLoginIdentity: mocks.findLoginIdentity,
  getRoleById: mocks.getRoleById,
  findUserWithRolesById: mocks.findUserWithRolesById,
}));

vi.mock('./providers/email.js', () => ({
  createEmailProvider: () => ({
    sendVerificationEmail: mocks.sendVerificationEmail,
  }),
}));

import { registerWithEmail } from './auth.service.js';

describe('email registration delivery failure', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.clientQuery.mockImplementation(async (query: string) =>
      query.includes('RETURNING id')
        ? { rows: [{ id: 'email-identity-1' }] }
        : { rows: [] },
    );
    mocks.poolConnect.mockResolvedValue({
      query: mocks.clientQuery,
      release: mocks.clientRelease,
    });
    mocks.findUserByEmail.mockResolvedValue(undefined);
    mocks.findLoginIdentity.mockResolvedValue(undefined);
    mocks.getRoleById.mockResolvedValue({ isPubliclyAssignable: true });
    mocks.findUserWithRolesById.mockResolvedValue({
      id: 'user-1',
      firstName: 'Jamila',
    });
    mocks.sendVerificationEmail.mockRejectedValue(new Error('provider offline'));
  });

  it('keeps the registered account recoverable and reports failed email delivery', async () => {
    const result = await registerWithEmail({
      firstName: 'Jamila',
      lastName: 'User',
      email: 'Jamila@Example.com',
      password: 'Secure-password-123!',
      role: 'house_seeker',
    });

    expect(result.verificationRequired).toBe(true);
    expect(result.verificationChannel).toBe('email');
    expect(result.verificationDeliveryFailed).toBe(true);
    expect(mocks.clientQuery).toHaveBeenCalledWith('COMMIT');
    expect(mocks.clientQuery).not.toHaveBeenCalledWith('ROLLBACK');
  });
});
