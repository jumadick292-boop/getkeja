import { beforeEach, describe, expect, it, vi } from 'vitest';

const { query } = vi.hoisted(() => ({ query: vi.fn() }));
vi.mock('../../db/pool.js', () => ({ pool: { query } }));

import { findProviders } from './provider-discovery.repository.js';
import { providerDiscoveryQuerySchema } from './provider-discovery.schema.js';

describe('findProviders', () => {
  beforeEach(() => {
    query.mockReset().mockResolvedValue({ rows: [] });
  });

  it('only searches approved profiles in active radius service areas', async () => {
    const input = providerDiscoveryQuerySchema.parse({
      latitude: -1.28,
      longitude: 36.8,
      category: 'moving_service_provider',
    });
    expect(await findProviders(input)).toEqual([]);
    const [sql, params] = query.mock.calls[0] as [string, unknown[]];
    expect(sql).toContain("sp.verification_status = 'approved'");
    expect(sql).toContain('area.is_active = TRUE');
    expect(sql).toContain('distance."distanceKm" <= area.radius_km');
    expect(sql).not.toContain('tenant');
    expect(params).toContain('moving_service_provider');
  });
});
