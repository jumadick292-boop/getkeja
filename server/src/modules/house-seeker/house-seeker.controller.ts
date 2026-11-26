import type { Request, Response } from 'express';
import type { AuthUser } from '../auth/auth.types.js';
import { ConflictError, ForbiddenError, HttpError } from '../../shared/errors.js';
import { pool } from '../../db/pool.js';
import * as repo from './house-seeker.repository.js';
import * as lifecycle from '../site-visits/site-visit-lifecycle.js';
import { PROPERTY_TIME_ZONE } from '../site-visits/site-visit.service.js';
import * as messagingService from '../messaging/messaging.service.js';
import { decodeMessageCursor as decodeCursor } from '../messaging/messaging.repository.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function getParam(req: AuthenticatedRequest, name: string): string {
  const value = req.params[name];
  if (value === undefined) return '';
  return (Array.isArray(value) ? value[0] : value) as string;
}

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

// ============================================================================
// Discovery
// ============================================================================
export async function search(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const result = await repo.searchListings(req.query as any);
  res.json(result);
}

export async function featured(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const [featuredListings, recent] = await Promise.all([
    repo.getFeaturedListings(),
    repo.getRecentlyPublished(),
  ]);
  res.json({ featured: featuredListings, recent });
}

export async function mapResults(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const items = await repo.getMapListings(req.query as any);
  res.json({ items, count: items.length });
}

export async function filters(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const facets = await repo.getFilterFacets();
  res.json(facets);
}

export async function getListing(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const listing = await repo.getPublicListingById(getParam(req, 'listingId'));
  res.json(listing);
}

export async function getRelatedListings(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const listingId = getParam(req, 'listingId');
  const query = req.query as unknown as { limit?: number; offset?: number };
  const result = await repo.getRelatedListings(listingId, {
    limit: query.limit ?? 6,
    offset: query.offset ?? 0,
  });
  res.json(result);
}

// ============================================================================
// Saved homes
// ============================================================================
export async function save(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const saved = await repo.saveListing(userId, req.body);
  res.status(201).json(saved);
}

export async function unsave(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.removeSavedListing(userId, getParam(req, 'listingId'));
  res.json(result);
}

export async function listSaved(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { collection?: string; limit: number; offset: number };
  const result = await repo.listSavedListings(userId, query);
  res.json(result);
}

// ============================================================================
// Saved searches
// ============================================================================
export async function createSearch(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const created = await repo.createSavedSearch(userId, req.body);
  res.status(201).json(created);
}

export async function listSearches(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const items = await repo.listSavedSearches(userId);
  res.json({ items });
}

export async function updateSearch(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const updated = await repo.updateSavedSearch(userId, getParam(req, 'searchId'), req.body);
  res.json(updated);
}

export async function removeSearch(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.deleteSavedSearch(userId, getParam(req, 'searchId'));
  res.json(result);
}

export async function runSavedSearch(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const searchId = getParam(req, 'searchId');
  const query = req.query as unknown as { limit?: number; offset?: number };
  const result = await repo.runSavedSearch(userId, searchId, {
    limit: query.limit ?? 20,
    offset: query.offset ?? 0,
  });
  res.json(result);
}

// ============================================================================
// Property comparison
// ============================================================================
export async function getComparison(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { limit?: number; offset?: number };
  const result = await repo.getComparisonList(userId, {
    limit: query.limit ?? 20,
    offset: query.offset ?? 0,
  });
  res.json(result);
}

export async function addToComparison(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.addToComparison(userId, req.body.listingId);
  res.status(201).json(result);
}

export async function removeFromComparison(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const listingId = getParam(req, 'listingId');
  const result = await repo.removeFromComparison(userId, listingId);
  res.json(result);
}

export async function clearComparison(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.clearComparison(userId);
  res.json(result);
}

// ============================================================================
// Enquiries (house seeker side)
// ============================================================================
export async function submitEnquiry(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const enquiry = await repo.createSeekerEnquiry(userId, req.body);
  res.status(201).json(enquiry);
}

export async function listEnquiries(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { status?: string; limit: number; offset: number };
  const result = await repo.listMyEnquiries(userId, query);
  res.json(result);
}

export async function getEnquiry(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const enquiry = await repo.findMyEnquiry(userId, getParam(req, 'enquiryId'));
  res.json(enquiry);
}

export async function withdraw(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.withdrawEnquiry(userId, getParam(req, 'enquiryId'));
  res.json(result);
}

// ============================================================================
// Preferences
// ============================================================================
export async function getPreferences(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const prefs = await repo.getPreferences(userId);
  res.json(prefs ?? {});
}

export async function updatePreferences(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const prefs = await repo.upsertPreferences(userId, req.body);
  res.json(prefs);
}

// ============================================================================
// Listing reports
// ============================================================================
export async function reportListing(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const report = await repo.createListingReport(userId, req.body);
  res.status(201).json(report);
}

// ============================================================================
// Site visits (house seeker side)
// ============================================================================

export async function requestSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as {
    propertyId: string;
    listingId?: string | null;
    unitId?: string | null;
    scheduledAt: string;
    durationMinutes?: number;
    visitorNotes?: string | null;
    phone?: string | null;
  };

  // Resolve the contact name/email server-side; never trust client-supplied
  // visitor identity for authenticated requests.
  const contact = await repo.findUserContact(userId);
  const phone = body.phone || contact?.phoneNumber || '';
  if (!phone) {
    throw new ConflictError('A contact phone number is required to request a visit');
  }

  const visit = await lifecycle.createVisitWithCheck({
    userId,
    propertyId: body.propertyId,
    listingId: body.listingId ?? null,
    unitId: body.unitId ?? null,
    scheduledAt: body.scheduledAt,
    durationMinutes: body.durationMinutes,
    visitorNotes: body.visitorNotes ?? null,
    phone,
    visitorName: contact?.name ?? null,
    visitorEmail: contact?.email ?? null,
  });

  // Outbox events are written inside the transaction. Hand the ids to the
  // worker so delivery starts promptly (best effort; the cron scan is a
  // safety net).
  await enqueueOutboxForVisit(visit.id);

  res.status(201).json(serializeVisit(visit));
}

/**
 * GET /house-seeker/listings/:listingId/availability?date=YYYY-MM-DD
 *
 * Returns the bookable slot grid for a listing on a given local date so the
 * client never has to guess availability. Times are interpreted in
 * Africa/Nairobi and returned as UTC ISO instants alongside their local
 * wall-clock label.
 */
export async function getListingAvailability(req: AuthenticatedRequest, res: Response) {
  assertAuth(req);
  const listingId = getParam(req, 'listingId');
  const date = (req.query as unknown as { date: string }).date;

  const listing = await pool.query<{ property_id: string; status: string }>(
    `SELECT property_id, status FROM property_listings WHERE id = $1`,
    [listingId],
  );
  const row = listing.rows[0];
  if (!row) throw new HttpError('Listing not found', 404);
  if (row.status !== 'published') throw new HttpError('Listing is not available', 409);

  const availability = await repo.getListingAvailability(row.property_id, date);
  res.json({
    propertyId: row.property_id,
    listingId,
    date,
    timezone: PROPERTY_TIME_ZONE,
    slots: availability.slots,
    unavailableReason: availability.unavailableReason ?? null,
  });
}

export async function listSiteVisits(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { status?: string; limit?: number; offset?: number };
  const limit = query.limit ?? 20;
  const offset = query.offset ?? 0;

  const conditions: string[] = ['user_id = $1'];
  const params: unknown[] = [userId];
  if (query.status) {
    params.push(query.status);
    conditions.push(`status = $${params.length}::visit_status`);
  }
  params.push(limit, offset);

  const result = await pool.query(
    `SELECT ${VISIT_SELECT_COLUMNS}
       FROM site_visits
      WHERE ${conditions.join(' AND ')}
      ORDER BY scheduled_at DESC
      LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );

  const totalResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::text AS count FROM site_visits WHERE user_id = $1`,
    [userId],
  );

  const items = result.rows.map(serializeVisit);
  res.json({ items, total: Number(totalResult.rows[0]?.count ?? items.length), limit, offset });
}

export async function getSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visit = await repo.getMySiteVisit(userId, getParam(req, 'visitId'));
  res.json(serializeVisit(visit));
}

export async function cancelSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  // Ownership is enforced inside cancelVisit via the caller's user id and the
  // seeker-side guard below.
  const visit = await repo.getMySiteVisit(userId, visitId);
  const reason = (req.body as { reason?: string } | undefined)?.reason ?? null;

  const updated = await lifecycle.cancelVisit({
    visitId,
    userId,
    reason,
    cancelledBy: 'seeker',
  });
  void visit;
  await enqueueOutboxForVisit(updated.id);
  res.json(serializeVisit(updated));
}

export async function rescheduleSiteVisit(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const visitId = getParam(req, 'visitId');
  await repo.getMySiteVisit(userId, visitId);

  const body = req.body as { scheduledAt: string };
  const updated = await lifecycle.rescheduleVisit({
    visitId,
    userId,
    scheduledAt: body.scheduledAt,
  });
  await enqueueOutboxForVisit(updated.id);
  res.json(serializeVisit(updated));
}

const VISIT_SELECT_COLUMNS = `
  id, property_id AS "propertyId", unit_id AS "unitId", user_id AS "userId",
  visitor_name AS "visitorName", visitor_email AS "visitorEmail",
  visitor_phone AS "visitorPhone", scheduled_at AS "scheduledAt",
  duration_minutes AS "durationMinutes", status,
  hosted_by_user_id AS "hostedByUserId",
  hosted_by_organisation_id AS "hostedByOrganisationId",
  visitor_notes AS "visitorNotes", host_notes AS "hostNotes", outcome,
  enquiry_id AS "enquiryId", assigned_to_user_id AS "assignedToUserId",
  created_by AS "createdBy", updated_by AS "updatedBy",
  created_at AS "createdAt", updated_at AS "updatedAt"`;

function serializeVisit(visit: object): Record<string, unknown> {
  const source = visit as Record<string, unknown>;
  const scheduledAt = source.scheduledAt;
  const createdAt = source.createdAt;
  const updatedAt = source.updatedAt;
  return {
    ...source,
    scheduledAt: scheduledAt instanceof Date ? scheduledAt.toISOString() : scheduledAt,
    createdAt: createdAt instanceof Date ? createdAt.toISOString() : createdAt,
    updatedAt: updatedAt instanceof Date ? updatedAt.toISOString() : updatedAt,
  };
}

async function enqueueOutboxForVisit(_visitId: string): Promise<void> {
  // Delivery is driven by the notification outbox worker, which polls pending
  // rows. Reminder scheduling is handled by the reminder worker scanning
  // site_visits. This hook exists so a future direct-queue optimisation has a
  // single call site without changing controller behaviour.
}

// ============================================================================
// Conversations & messages (house seeker side)
//
// These delegate to the centralized messaging service so seeker and landlord
// threads share one set of authorization, dedup, pagination and notification
// rules. The response shapes are preserved for the existing Flutter client.
// ============================================================================
export async function startConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as {
    propertyId?: string;
    landlordUserId?: string;
    listingId?: string;
    unitId?: string;
    subject?: string;
    message?: string;
    enquiryId?: string;
    siteVisitId?: string;
  };
  const result = await messagingService.startConversation(userId, {
    type: body.enquiryId ? 'enquiry' : body.siteVisitId ? 'site_visit' : 'general',
    propertyId: body.propertyId ?? null,
    unitId: body.unitId ?? null,
    enquiryId: body.enquiryId ?? null,
    siteVisitId: body.siteVisitId ?? null,
    subject: body.subject ?? null,
    participantUserIds: body.landlordUserId ? [body.landlordUserId] : [],
    message: body.message ?? null,
  });
  res.status(result.reused ? 200 : 201).json({
    conversation: result.conversation,
    firstMessage: result.firstMessage,
  });
}

export async function listConversations(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { limit?: number; offset?: number; status?: string };
  const result = await messagingService.listMyConversations(userId, {
    limit: query.limit ?? 20,
    offset: query.offset ?? 0,
    status: query.status,
  });
  res.json({ items: result.items, total: result.total, limit: result.limit, offset: result.offset });
}

export async function getConversation(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await messagingService.getMyConversation(userId, getParam(req, 'conversationId')));
}

export async function listMessages(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { limit?: number; before?: string };
  const result = await messagingService.listMyMessages(userId, getParam(req, 'conversationId'), {
    limit: query.limit ?? 50,
    before: typeof query.before === 'string' ? decodeCursor(query.before) : null,
  });
  res.json({ items: result.items, hasMore: result.hasMore });
}

export async function sendMessage(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { conversationId: string; content: string };
  const message = await messagingService.sendMessage(userId, {
    conversationId: body.conversationId,
    content: body.content,
  });
  res.status(201).json(message);
}

export async function markRead(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json(await messagingService.markConversationRead(userId, getParam(req, 'conversationId')));
}

// ============================================================================
// Rental applications (house seeker side)
// ============================================================================
export async function submitApplication(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const application = await repo.createSeekerApplication(userId, req.body);
  res.status(201).json(application);
}

export async function listApplications(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { status?: string; limit: number; offset: number };
  const result = await repo.listMyApplications(userId, query);
  res.json(result);
}

export async function getApplication(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const application = await repo.getMyApplication(userId, getParam(req, 'applicationId'));
  res.json(application);
}

export async function withdrawApplication(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.withdrawMyApplication(userId, getParam(req, 'applicationId'));
  res.json(result);
}

// ============================================================================
// Rental proposals (house seeker responses)
// ============================================================================
export async function listProposals(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const query = req.query as unknown as { status?: string; limit: number; offset: number };
  const result = await repo.listMyProposals(userId, query);
  res.json(result);
}

export async function getProposal(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const proposal = await repo.getMyProposal(userId, getParam(req, 'proposalId'));
  res.json(proposal);
}

export async function respondToProposal(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const result = await repo.respondToMyProposal(userId, getParam(req, 'proposalId'), req.body);
  res.json(result);
}

// ============================================================================
// Rental journey
// ============================================================================
export async function getJourney(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const journey = await repo.getSeekerJourney(userId);
  res.json(journey);
}