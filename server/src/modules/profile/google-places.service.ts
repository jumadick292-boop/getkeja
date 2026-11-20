import { loadEnv } from '../../config/env.js';
import { HttpError } from '../../shared/errors.js';

const PLACES_BASE = 'https://places.googleapis.com/v1';
const timeoutMs = 5_000;

export type PlaceSuggestion = {
  placeId: string;
  description: string;
};

export type PlaceDetails = {
  placeId: string;
  formattedAddress: string | null;
  latitude: number;
  longitude: number;
  country: string | null;
  countryCode: string | null;
  county: string | null;
  city: string | null;
  neighborhood: string | null;
};

function apiKey(): string {
  const key = loadEnv().GOOGLE_MAPS_SERVER_API_KEY;
  if (!key) throw new HttpError('Place search is not configured; use the map pin or text fields', 503);
  return key;
}

async function placesFetch(url: string, init: RequestInit): Promise<Record<string, any>> {
  try {
    const response = await fetch(url, {
      ...init,
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) throw new HttpError('Place search is temporarily unavailable', 502);
    const data: unknown = await response.json();
    if (!data || typeof data !== 'object') throw new HttpError('Invalid response from place search', 502);
    return data as Record<string, any>;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError('Place search is temporarily unavailable; choose a map pin or enter the location manually', 503);
  }
}

export async function autocomplete(input: string): Promise<PlaceSuggestion[]> {
  const data = await placesFetch(`${PLACES_BASE}/places:autocomplete`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'X-Goog-Api-Key': apiKey(),
    },
    body: JSON.stringify({ input }),
  });
  const suggestions = Array.isArray(data.suggestions) ? data.suggestions : [];
  return suggestions.flatMap((item: any) => {
    const place = item?.placePrediction;
    const placeId = place?.placeId;
    const description = place?.text?.text;
    return typeof placeId === 'string' && typeof description === 'string'
      ? [{ placeId, description }]
      : [];
  });
}

export async function details(placeId: string): Promise<PlaceDetails> {
  const data = await placesFetch(`${PLACES_BASE}/places/${encodeURIComponent(placeId)}`, {
    headers: {
      'X-Goog-Api-Key': apiKey(),
      'X-Goog-FieldMask': 'id,formattedAddress,location,addressComponents',
    },
  });
  const latitude = data.location?.latitude;
  const longitude = data.location?.longitude;
  if (typeof latitude !== 'number' || typeof longitude !== 'number' ||
      latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    throw new HttpError('Place search returned invalid coordinates', 502);
  }
  const components = Array.isArray(data.addressComponents) ? data.addressComponents : [];
  const component = (...types: string[]): string | null => {
    const found = components.find((item: any) => types.some((type) => item.types?.includes(type)));
    return typeof found?.longText === 'string' ? found.longText : null;
  };
  return {
    placeId: typeof data.id === 'string' ? data.id : placeId,
    formattedAddress: typeof data.formattedAddress === 'string' ? data.formattedAddress : null,
    latitude,
    longitude,
    country: component('country'),
    countryCode: typeof components.find((item: any) => item.types?.includes('country'))?.shortText === 'string'
      ? components.find((item: any) => item.types?.includes('country')).shortText
      : null,
    county: component('administrative_area_level_2', 'administrative_area_level_1'),
    city: component('locality', 'postal_town', 'administrative_area_level_3'),
    neighborhood: component('neighborhood', 'sublocality', 'sublocality_level_1'),
  };
}
