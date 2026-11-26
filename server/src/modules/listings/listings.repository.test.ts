import { beforeEach, describe, expect, it, vi } from 'vitest';

const { query } = vi.hoisted(() => ({ query: vi.fn() }));
vi.mock('../../db/pool.js', () => ({ pool: { query } }));

import { findNearbyListings } from './listings.repository.js';
import { nearbyListingsQuerySchema } from './listings.schema.js';

describe('findNearbyListings', () => {
  beforeEach(() => {
    query.mockReset();
    query.mockResolvedValueOnce({ rows: [{ total: 1 }] });
    query.mockResolvedValueOnce({
      rows: [{ id: 'listing-id', latitude: -1.28, longitude: 36.8 }],
    });
  });

  it('only returns published properties and rounds coordinates', async () => {
    const input = nearbyListingsQuerySchema.parse({
      latitude: -1.28,
      longitude: 36.8,
      radiusKm: 15,
    });
    const result = await findNearbyListings(input);
    expect(result.total).toBe(1);
    expect(query).toHaveBeenCalledTimes(2);
    const [sql, params] = query.mock.calls[1] as [string, unknown[]];
    expect(sql).toContain("p.status = 'published'");
    expect(sql).toContain('round(p.latitude::numeric, 3)');
    expect(sql).toContain('"distanceKm"');
    expect(sql).not.toContain('p.address, p.city');
    expect(params).toContain(-1.28);
    expect(params).toContain(36.8);
    expect(params).toContain(15);
  });

  it('supports map bounds crossing the antimeridian', async () => {
    const input = nearbyListingsQuerySchema.parse({
      north: 10,
      south: -10,
      east: -170,
      west: 170,
    });
    await findNearbyListings(input);
    const [sql] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain('p.longitude >=');
    expect(sql).toContain('OR p.longitude <=');
  });
});
