import { afterEach, describe, expect, it, vi } from 'vitest';
import { autocomplete, details } from './google-places.service.js';

describe('Google Places proxy', () => {
  afterEach(() => {
    delete process.env.GOOGLE_MAPS_SERVER_API_KEY;
    vi.unstubAllGlobals();
  });

  it('returns place suggestions without exposing the server key to clients', async () => {
    process.env.GOOGLE_MAPS_SERVER_API_KEY = 'restricted-server-test-key';
    const fetchMock = vi.fn(async (_url: string | URL | Request, init?: RequestInit) => {
      expect(new Headers(init?.headers).get('X-Goog-Api-Key')).toBe('restricted-server-test-key');
      return Response.json({ suggestions: [{ placePrediction: {
        placeId: 'place-123', text: { text: 'Westlands, Nairobi' },
      } }] });
    });
    vi.stubGlobal('fetch', fetchMock);

    await expect(autocomplete('Westlands')).resolves.toEqual([
      { placeId: 'place-123', description: 'Westlands, Nairobi' },
    ]);
  });

  it('returns coordinates and normalized address components for a selected place', async () => {
    process.env.GOOGLE_MAPS_SERVER_API_KEY = 'restricted-server-test-key';
    vi.stubGlobal('fetch', vi.fn(async () => Response.json({
      id: 'place-123',
      formattedAddress: 'Westlands, Nairobi, Kenya',
      location: { latitude: -1.2676, longitude: 36.8108 },
      addressComponents: [
        { longText: 'Kenya', shortText: 'KE', types: ['country'] },
        { longText: 'Nairobi County', types: ['administrative_area_level_1'] },
        { longText: 'Nairobi', types: ['locality'] },
        { longText: 'Westlands', types: ['neighborhood'] },
      ],
    })));

    await expect(details('place-123')).resolves.toMatchObject({
      placeId: 'place-123', latitude: -1.2676, longitude: 36.8108,
      country: 'Kenya', countryCode: 'KE', county: 'Nairobi County', city: 'Nairobi',
      neighborhood: 'Westlands',
    });
  });

  it('returns a service-unavailable response when Maps credentials are absent', async () => {
    await expect(autocomplete('Nairobi')).rejects.toMatchObject({ status: 503 });
  });
});
