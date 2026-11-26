import { pool } from '../../db/pool.js';
import { HttpError } from '../../shared/errors.js';
import type {
  DirectionsRequest,
  NearbyListingsQuery,
} from './listings.schema.js';

export async function findNearbyListings(query: NearbyListingsQuery) {
  const values: unknown[] = [];
  const where = [
    "p.status = 'published'",
    "EXISTS (SELECT 1 FROM units available_units WHERE available_units.property_id = p.id AND available_units.status = 'vacant')",
  ];
  const bind = (value: unknown) => {
    values.push(value);
    return `$${values.length}`;
  };

  if (query.north !== undefined && query.south !== undefined) {
    const north = bind(query.north);
    const south = bind(query.south);
    where.push(`p.latitude BETWEEN ${south} AND ${north}`);
    if (query.wrapsAntimeridian) {
      const west = bind(query.west);
      const east = bind(query.east);
      where.push(`(p.longitude >= ${west} OR p.longitude <= ${east})`);
    } else {
      const west = bind(query.west);
      const east = bind(query.east);
      where.push(`p.longitude BETWEEN ${west} AND ${east}`);
    }
  } else if (query.latitude !== undefined && query.longitude !== undefined) {
    const lat = query.latitude;
    const lon = query.longitude;
    const latDelta = query.radiusKm / 110.574;
    const lonDelta =
      query.radiusKm / Math.max(1, 111.32 * Math.cos((lat * Math.PI) / 180));
    const minLat = bind(Math.max(-90, lat - latDelta));
    const maxLat = bind(Math.min(90, lat + latDelta));
    where.push(`p.latitude BETWEEN ${minLat} AND ${maxLat}`);
    // Near the poles a longitude degree spans very little distance, so omit
    // this prefilter and let the exact Haversine test decide.
    if (Math.abs(lat) < 85) {
      const minLonValue = lon - lonDelta;
      const maxLonValue = lon + lonDelta;
      if (minLonValue < -180 || maxLonValue > 180) {
        const west = bind(((minLonValue + 540) % 360) - 180);
        const east = bind(((maxLonValue + 540) % 360) - 180);
        where.push(`(p.longitude >= ${west} OR p.longitude <= ${east})`);
      } else {
        const minLon = bind(minLonValue);
        const maxLon = bind(maxLonValue);
        where.push(`p.longitude BETWEEN ${minLon} AND ${maxLon}`);
      }
    }
  }
  if (query.city) where.push(`p.city ILIKE ${bind(`%${query.city}%`)}`);
  if (query.county) where.push(`p.county ILIKE ${bind(`%${query.county}%`)}`);
  if (query.propertyType)
    where.push(`p.property_type = ${bind(query.propertyType)}`);
  const unitFilters = [
    'filter_units.property_id = p.id',
    "filter_units.status = 'vacant'",
  ];
  if (query.rentMin !== undefined)
    unitFilters.push(`filter_units.rent_amount >= ${bind(query.rentMin)}`);
  if (query.rentMax !== undefined)
    unitFilters.push(`filter_units.rent_amount <= ${bind(query.rentMax)}`);
  if (query.bedrooms !== undefined)
    unitFilters.push(`filter_units.bedrooms = ${bind(query.bedrooms)}`);
  if (unitFilters.length > 2) {
    where.push(
      `EXISTS (SELECT 1 FROM units filter_units WHERE ${unitFilters.join(' AND ')})`,
    );
  }
  if (query.q) {
    const search = bind(`%${query.q}%`);
    where.push(
      `(p.title ILIKE ${search} OR p.address ILIKE ${search} OR p.city ILIKE ${search} OR p.county ILIKE ${search})`,
    );
  }

  let distanceSql = 'NULL::double precision';
  if (query.latitude !== undefined && query.longitude !== undefined) {
    const lat = bind(query.latitude);
    const lon = bind(query.longitude);
    distanceSql = `6371 * acos(LEAST(1, GREATEST(-1,
      cos(radians(${lat})) * cos(radians(p.latitude::double precision)) *
      cos(radians(p.longitude::double precision) - radians(${lon})) +
      sin(radians(${lat})) * sin(radians(p.latitude::double precision))
    )))`;
    where.push(`${distanceSql} <= ${bind(query.radiusKm)}`);
  }
  const count = await pool.query(
    `SELECT count(*)::int AS total FROM properties p WHERE ${where.join(' AND ')}`,
    values,
  );

  const limit = bind(query.limit);
  const offset = bind(query.offset);
  const result = await pool.query(
    `SELECT p.id, p.title, p.description, p.property_type AS "propertyType",
            p.city, p.county, p.country,
            CASE WHEN p.latitude IS NULL THEN NULL ELSE round(p.latitude::numeric, 3) END AS latitude,
            CASE WHEN p.longitude IS NULL THEN NULL ELSE round(p.longitude::numeric, 3) END AS longitude,
            CASE WHEN ${distanceSql} IS NULL THEN NULL
                 ELSE round((${distanceSql})::numeric, 1)::double precision END AS "distanceKm",
            availability."availableUnitCount", availability."minimumRent",
            availability."unitTypes", p.images, p.amenities, p.published_at AS "publishedAt"
       FROM properties p
       JOIN LATERAL (
         SELECT count(*)::int AS "availableUnitCount",
                min(NULLIF(u.rent_amount, 0)) AS "minimumRent",
                array_agg(DISTINCT u.unit_type ORDER BY u.unit_type) AS "unitTypes"
           FROM units u WHERE u.property_id = p.id AND u.status = 'vacant'
       ) availability ON TRUE
      WHERE ${where.join(' AND ')}
      ORDER BY ${query.latitude !== undefined ? '"distanceKm" ASC,' : ''} p.published_at DESC NULLS LAST, p.id
      LIMIT ${limit} OFFSET ${offset}`,
    values,
  );
  return {
    items: result.rows,
    total: count.rows[0]?.total ?? 0,
    limit: query.limit,
    offset: query.offset,
  };
}

export async function calculateRoute(request: DirectionsRequest) {
  const apiKey = process.env.GOOGLE_ROUTES_API_KEY;
  if (!apiKey) throw new HttpError('Route preview is not configured', 503);
  let response: Response;
  try {
    response = await fetch(
      'https://routes.googleapis.com/directions/v2:computeRoutes',
      {
        method: 'POST',
        signal: AbortSignal.timeout(8_000),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
            'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline,routes.description',
        },
        body: JSON.stringify({
          origin: {
            location: {
              latLng: {
                latitude: request.origin.latitude,
                longitude: request.origin.longitude,
              },
            },
          },
          destination: {
            location: {
              latLng: {
                latitude: request.destination.latitude,
                longitude: request.destination.longitude,
              },
            },
          },
          travelMode: request.travelMode,
          polylineQuality: 'OVERVIEW',
          computeAlternativeRoutes: true,
        }),
      },
    );
  } catch {
    throw new HttpError('Route provider is unavailable', 502);
  }
  if (!response.ok)
    throw new HttpError('Route provider could not calculate this route', 502);
  const data = (await response.json()) as { routes?: unknown[] };
  return { routes: data.routes ?? [], travelMode: request.travelMode };
}
