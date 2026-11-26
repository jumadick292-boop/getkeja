import { describe, expect, it } from 'vitest';
import { providerDiscoveryQuerySchema } from './provider-discovery.schema.js';

describe('providerDiscoveryQuerySchema', () => {
  it('validates coordinates, categories, and paging limits', () => {
    expect(
      providerDiscoveryQuerySchema.parse({
        latitude: '-1.28',
        longitude: '36.8',
      }),
    ).toMatchObject({
      latitude: -1.28,
      longitude: 36.8,
      limit: 20,
    });
    expect(
      providerDiscoveryQuerySchema.safeParse({ latitude: 91, longitude: 0 })
        .success,
    ).toBe(false);
    expect(
      providerDiscoveryQuerySchema.safeParse({
        latitude: 0,
        longitude: 0,
        category: 'house_seeker',
      }).success,
    ).toBe(false);
  });
});
