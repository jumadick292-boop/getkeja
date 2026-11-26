import { pool } from '../../db/pool.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import type { startSharingSchema, updateLocationSchema } from './location-sharing.schema.js';
import type { z } from 'zod';

type StartInput = z.infer<typeof startSharingSchema>;
type UpdateInput = z.infer<typeof updateLocationSchema>;

export async function start(userId: string, input: StartInput) {
  if (userId === input.recipientUserId) {
    throw new ValidationError('You cannot share a location with yourself');
  }
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const visit = await client.query(
      `SELECT id FROM site_visits
        WHERE id = $1 AND status IN ('scheduled', 'confirmed')
          AND ((user_id = $2 AND hosted_by_user_id = $3)
            OR (hosted_by_user_id = $2 AND user_id = $3))
        LIMIT 1 FOR SHARE`,
      [input.siteVisitId, userId, input.recipientUserId],
    );
    if (!visit.rowCount) {
      throw new ForbiddenError('Location sharing is only available with the other user on an active site visit');
    }
    const active = await client.query(
      `SELECT 1 FROM location_sharing_sessions
        WHERE site_visit_id = $1 AND sharer_user_id = $2 AND recipient_user_id = $3
          AND revoked_at IS NULL AND expires_at > NOW()
        LIMIT 1`,
      [input.siteVisitId, userId, input.recipientUserId],
    );
    if (active.rowCount) throw new ConflictError('A location-sharing session is already active for this visit');
    const result = await client.query(
      `INSERT INTO location_sharing_sessions
         (site_visit_id, sharer_user_id, recipient_user_id, expires_at)
       VALUES ($1, $2, $3, NOW() + ($4 * INTERVAL '1 minute'))
       RETURNING id, site_visit_id AS "siteVisitId", recipient_user_id AS "recipientUserId",
                 created_at AS "startedAt", expires_at AS "expiresAt"`,
      [input.siteVisitId, userId, input.recipientUserId, input.durationMinutes],
    );
    await client.query(
      `INSERT INTO authorization_audit
         (user_id, decision, permission_id, resource_type, resource_id, metadata)
       VALUES ($1, 'allow', 'location.share.start', 'location_sharing_session', $2, $3)`,
      [userId, result.rows[0].id, JSON.stringify({ siteVisitId: input.siteVisitId, recipientUserId: input.recipientUserId, durationMinutes: input.durationMinutes })],
    );
    await client.query('COMMIT');
    return result.rows[0];
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function update(userId: string, sessionId: string, input: UpdateInput) {
  const result = await pool.query(
    `UPDATE location_sharing_sessions
        SET latitude = $3, longitude = $4, accuracy_meters = $5, location_updated_at = NOW()
      WHERE id = $1 AND sharer_user_id = $2 AND revoked_at IS NULL AND expires_at > NOW()
        AND (location_updated_at IS NULL OR location_updated_at <= NOW() - INTERVAL '15 seconds')
      RETURNING id, location_updated_at AS "updatedAt", expires_at AS "expiresAt"`,
    [sessionId, userId, input.latitude, input.longitude, input.accuracyMeters ?? null],
  );
  if (result.rows[0]) return result.rows[0];
  const current = await pool.query(
    `SELECT 1 FROM location_sharing_sessions
      WHERE id = $1 AND sharer_user_id = $2 AND revoked_at IS NULL AND expires_at > NOW()`,
    [sessionId, userId],
  );
  if (!current.rowCount) throw new NotFoundError('Active sharing session');
  throw new ValidationError('Location updates may be sent no more often than every 15 seconds');
}

export async function listOwned(userId: string) {
  const result = await pool.query(
    `SELECT id, site_visit_id AS "siteVisitId", recipient_user_id AS "recipientUserId",
            created_at AS "startedAt", expires_at AS "expiresAt", revoked_at AS "stoppedAt",
            location_updated_at AS "lastLocationUpdateAt",
            (revoked_at IS NULL AND expires_at > NOW()) AS active
       FROM location_sharing_sessions
      WHERE sharer_user_id = $1 ORDER BY created_at DESC LIMIT 100`,
    [userId],
  );
  return result.rows;
}

export async function listEligibleVisits(userId: string) {
  const result = await pool.query(
    `SELECT sv.id AS "siteVisitId", sv.scheduled_at AS "scheduledAt",
            p.title AS "propertyTitle", p.city,
            CASE WHEN sv.user_id = $1 THEN sv.hosted_by_user_id ELSE sv.user_id END AS "recipientUserId",
            CASE WHEN sv.user_id = $1
              THEN COALESCE(NULLIF(trim(concat_ws(' ', host.first_name, host.last_name)), ''), 'Site visit host')
              ELSE COALESCE(NULLIF(sv.visitor_name, ''), 'Site visit guest')
            END AS "recipientName"
       FROM site_visits sv
       JOIN properties p ON p.id = sv.property_id
       LEFT JOIN users host ON host.id = sv.hosted_by_user_id
      WHERE sv.status IN ('scheduled', 'confirmed')
        AND ((sv.user_id = $1 AND sv.hosted_by_user_id IS NOT NULL)
          OR (sv.hosted_by_user_id = $1 AND sv.user_id IS NOT NULL))
      ORDER BY sv.scheduled_at DESC LIMIT 100`,
    [userId],
  );
  return result.rows;
}

export async function listSharedWithMe(userId: string) {
  const result = await pool.query(
    `SELECT lss.id, lss.site_visit_id AS "siteVisitId", lss.sharer_user_id AS "sharerUserId",
            lss.created_at AS "startedAt", lss.expires_at AS "expiresAt",
            lss.location_updated_at AS "lastLocationUpdateAt",
            COALESCE(NULLIF(trim(concat_ws(' ', sharer.first_name, sharer.last_name)), ''), 'Site visit participant') AS "sharerName"
       FROM location_sharing_sessions lss
       JOIN users sharer ON sharer.id = lss.sharer_user_id
      WHERE lss.recipient_user_id = $1 AND lss.revoked_at IS NULL AND lss.expires_at > NOW()
      ORDER BY lss.created_at DESC LIMIT 100`,
    [userId],
  );
  return result.rows;
}

export async function retrieveSharedLocation(recipientUserId: string, sessionId: string) {
  const result = await pool.query(
    `SELECT latitude, longitude, accuracy_meters AS "accuracyMeters",
            location_updated_at AS "updatedAt", expires_at AS "expiresAt"
       FROM location_sharing_sessions
      WHERE id = $1 AND recipient_user_id = $2 AND revoked_at IS NULL
        AND expires_at > NOW() AND latitude IS NOT NULL`,
    [sessionId, recipientUserId],
  );
  if (!result.rows[0]) throw new NotFoundError('Active shared location');
  return result.rows[0];
}

export async function stop(userId: string, sessionId: string) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      `UPDATE location_sharing_sessions
          SET revoked_at = NOW(), latitude = NULL, longitude = NULL,
              accuracy_meters = NULL, location_updated_at = NULL
        WHERE id = $1 AND sharer_user_id = $2 AND revoked_at IS NULL
        RETURNING id`,
      [sessionId, userId],
    );
    if (!result.rowCount) throw new NotFoundError('Active sharing session');
    await client.query(
      `INSERT INTO authorization_audit
         (user_id, decision, permission_id, resource_type, resource_id)
       VALUES ($1, 'allow', 'location.share.stop', 'location_sharing_session', $2)`,
      [userId, sessionId],
    );
    await client.query('COMMIT');
    return { stopped: true };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

export async function cleanupExpired() {
  await pool.query(
    `UPDATE location_sharing_sessions
        SET latitude = NULL, longitude = NULL, accuracy_meters = NULL,
            location_updated_at = NULL
      WHERE expires_at <= NOW() AND latitude IS NOT NULL`,
  );
  await pool.query(
    `DELETE FROM location_sharing_sessions WHERE expires_at < NOW() - INTERVAL '90 days'`,
  );
}
