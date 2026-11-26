import { describe, expect, it } from 'vitest';
import {
  startSharingSchema,
  updateLocationSchema,
} from './location-sharing.schema.js';

describe('location sharing validation', () => {
  it('accepts only supported, bounded sharing durations', () => {
    const input = {
      siteVisitId: crypto.randomUUID(),
      recipientUserId: crypto.randomUUID(),
      durationMinutes: 480,
    };
    expect(startSharingSchema.safeParse(input).success).toBe(true);
    expect(
      startSharingSchema.safeParse({ ...input, durationMinutes: 1440 }).success,
    ).toBe(false);
  });

  it('validates GPS coordinate and accuracy ranges', () => {
    expect(
      updateLocationSchema.safeParse({
        latitude: -1.28,
        longitude: 36.8,
        accuracyMeters: 20,
      }).success,
    ).toBe(true);
    expect(
      updateLocationSchema.safeParse({ latitude: 91, longitude: 36.8 }).success,
    ).toBe(false);
    expect(
      updateLocationSchema.safeParse({ latitude: 0, longitude: 181 }).success,
    ).toBe(false);
  });
});
