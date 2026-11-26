import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ForbiddenError } from '../../shared/errors.js';

const { query, connect, clientQuery, release } = vi.hoisted(() => ({
  query: vi.fn(),
  connect: vi.fn(),
  clientQuery: vi.fn(),
  release: vi.fn(),
}));
vi.mock('../../db/pool.js', () => ({ pool: { query, connect } }));

import { start } from './location-sharing.repository.js';

describe('location sharing repository', () => {
  beforeEach(() => {
    query.mockReset();
    release.mockReset();
    clientQuery.mockReset();
    connect.mockReset().mockResolvedValue({ query: clientQuery, release });
    clientQuery.mockResolvedValue({ rows: [], rowCount: 0 });
  });

  it('requires the caller and recipient to be the two users on an active visit', async () => {
    await expect(
      start('caller', {
        siteVisitId: 'visit-id',
        recipientUserId: 'recipient',
        durationMinutes: 15,
      }),
    ).rejects.toBeInstanceOf(ForbiddenError);

    const authorizationQuery = clientQuery.mock.calls[1]?.[0] as string;
    expect(authorizationQuery).toContain(
      "status IN ('scheduled', 'confirmed')",
    );
    expect(authorizationQuery).toContain('user_id = $2');
    expect(authorizationQuery).toContain('hosted_by_user_id = $3');
    expect(clientQuery).toHaveBeenCalledWith('ROLLBACK');
    expect(release).toHaveBeenCalledOnce();
  });

  it('creates only one active session for the selected visit and audits the explicit share', async () => {
    clientQuery
      .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // BEGIN
      .mockResolvedValueOnce({ rows: [{ id: 'visit-id' }], rowCount: 1 })
      .mockResolvedValueOnce({ rows: [], rowCount: 0 })
      .mockResolvedValueOnce({
        rows: [{ id: 'session-id', expiresAt: new Date() }],
        rowCount: 1,
      })
      .mockResolvedValueOnce({ rows: [], rowCount: 1 })
      .mockResolvedValueOnce({ rows: [], rowCount: 0 }); // COMMIT

    const session = await start('caller', {
      siteVisitId: 'visit-id',
      recipientUserId: 'recipient',
      durationMinutes: 30,
    });

    expect(session.id).toBe('session-id');
    expect(
      clientQuery.mock.calls.some(([sql]) =>
        String(sql).includes('location.share.start'),
      ),
    ).toBe(true);
    expect(
      clientQuery.mock.calls.some(([sql]) => String(sql).includes('latitude')),
    ).toBe(false);
    expect(release).toHaveBeenCalledOnce();
  });
});
