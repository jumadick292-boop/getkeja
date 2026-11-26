import { describe, expect, it } from 'vitest';
import {
  directionsRequestSchema,
  nearbyListingsQuerySchema,
} from './listings.schema.js';

describe('nearbyListingsQuerySchema', () => {
  it('accepts a center search and applies safe pagination defaults', () => {
    expect(
      nearbyListingsQuerySchema.parse({ latitude: '-1.28', longitude: '36.8' }),
    ).toMatchObject({
      latitude: -1.28,
      longitude: 36.8,
      radiusKm: 10,
      limit: 20,
      offset: 0,
      wrapsAntimeridian: false,
    });
  });

  it('requires complete viewport bounds and enforces coordinate limits', () => {
    expect(
      nearbyListingsQuerySchema.safeParse({ north: 1, south: 0 }).success,
    ).toBe(false);
    expect(
      nearbyListingsQuerySchema.safeParse({ latitude: 91, longitude: 0 })
        .success,
    ).toBe(false);
    expect(nearbyListingsQuerySchema.safeParse({ latitude: 1 }).success).toBe(
      false,
    );
  });

  it('supports viewports crossing the antimeridian', () => {
    expect(
      nearbyListingsQuerySchema.parse({
        north: 10,
        south: -10,
        east: -170,
        west: 170,
      }),
    ).toMatchObject({ wrapsAntimeridian: true });
  });

  it('allows text-only locality discovery without requesting device location', () => {
    expect(nearbyListingsQuerySchema.parse({ q: 'Kilimani' }).q).toBe(
      'Kilimani',
    );
  });

  it('validates route endpoints and supported travel modes', () => {
    expect(
      directionsRequestSchema.safeParse({
        origin: { latitude: -1.2, longitude: 36.8 },
        destination: { latitude: -1.3, longitude: 36.9 },
        travelMode: 'WALK',
      }).success,
    ).toBe(true);
    expect(
      directionsRequestSchema.safeParse({
        origin: { latitude: 91, longitude: 36.8 },
        destination: { latitude: -1.3, longitude: 36.9 },
      }).success,
    ).toBe(false);
  });

  it('rejects an inverted rent range', () => {
    expect(
      nearbyListingsQuerySchema.safeParse({
        q: 'Kilimani',
        rentMin: 40_000,
        rentMax: 10_000,
      }).success,
    ).toBe(false);
  });
});
