// Provider reviews service (Task 13.16). Eligibility is enforced from the
// authoritative operational resource: the customer must own a completed+confirmed
// job, one review per job (DB unique), and only the owning provider may respond.
// Ratings use published reviews only. Moderation is platform-admin only and audited.
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import { enqueueOutboxEventTransactional } from '../auth/transactional-outbox.service.js';
import { isOperationalDomain, isReviewEligible, loadOperationalResource } from '../../shared/operationalResources.js';
import type { CreateReviewInput, ModerateReviewInput } from './reviews.schemas.js';
import * as repo from './reviews.repository.js';

async function emit(client: Parameters<Parameters<typeof transaction>[0]>[0], eventType: string, resourceType: string, resourceId: string, recipientUserIds: string[], payload: Record<string, unknown>) {
  await enqueueOutboxEventTransactional(client, {
    idempotencyKey: `${eventType}:${resourceId}`,
    eventType,
    category: 'reputation',
    priority: 'normal',
    recipientUserIds,
    organisationId: null,
    resourceType,
    resourceId,
    payload,
    channels: ['in_app'],
    classification: 'critical',
  });
}

export async function submitReview(userId: string, domain: string, resourceId: string, input: CreateReviewInput) {
  if (!isOperationalDomain(domain)) throw new ValidationError('Unsupported operational domain');
  const ref = await loadOperationalResource(domain, resourceId);
  if (!ref) throw new NotFoundError('Operational job not found');
  if (ref.customerUserId !== userId) throw new ForbiddenError('You may only review your own jobs');
  if (!isReviewEligible(ref)) throw new ConflictError('Job is not in a reviewable completed state');
  const existing = await repo.findByResource(domain, resourceId);
  if (existing) throw new ConflictError('A review already exists for this job');

  const created = await transaction(async (client) => {
    // Re-check under a row lock to avoid duplicate concurrent reviews.
    await client.query(`SELECT id FROM provider_reviews WHERE resource_domain = $1 AND resource_id = $2 FOR UPDATE`, [domain, resourceId]);
    const dup = await repo.findByResource(domain, resourceId);
    if (dup) return dup;
    const row = await repo.insertReview(client, {
      domain, resourceId, customerUserId: userId, providerProfileId: ref.providerProfileId,
      providerOrganisationId: ref.providerOrganisationId, overallRating: input.overallRating,
      comment: input.comment ?? null, qualityRating: input.qualityRating ?? null,
      professionalismRating: input.professionalismRating ?? null, timelinessRating: input.timelinessRating ?? null,
      valueRating: input.valueRating ?? null,
    });
    await emit(client, 'review.submitted', 'provider_review', row.id, [ref.customerUserId], { reviewId: row.id });
    return row;
  });
  return repo.findById(created.id);
}

export async function listProviderReviews(userId: string, organizationId: string | null | undefined, status?: string, limit = 20, offset = 0) {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No provider context');
  return repo.listForProvider(context.effectiveProfileIds, status, limit, offset);
}

export async function listCustomerReviews(userId: string, limit = 20, offset = 0) {
  return repo.listForCustomer(userId, limit, offset);
}

export async function getReview(userId: string, reviewId: string) {
  const review = await repo.findById(reviewId);
  if (!review) throw new NotFoundError('Review not found');
  // Customer can see own review; provider can see if they own the job profile.
  if (review.customerUserId === userId) return review;
  const context = await resolveProviderContext(userId, null);
  if (context.isProvider && context.effectiveProfileIds.includes(review.providerProfileId)) return review;
  if (await authz.hasPermission(userId, 'review.moderate')) return review;
  throw new ForbiddenError('Not authorized for this review');
}

export async function respondToReview(userId: string, organizationId: string | null | undefined, reviewId: string, response: string) {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No provider context');
  const review = await repo.findById(reviewId);
  if (!review) throw new NotFoundError('Review not found');
  if (!context.effectiveProfileIds.includes(review.providerProfileId)) throw new ForbiddenError('Not your review to respond to');
  if (await authz.hasPermission(userId, 'provider.reviews.respond') === false && context.activeOrganizationId) {
    const roleIds = await authz.getUserOrganizationRoleIds(userId, context.activeOrganizationId);
    if (!roleIds.some((r) => ['organization_owner', 'organization_admin'].includes(r))) {
      throw new ForbiddenError('Missing permission: provider.reviews.respond');
    }
  }
  await transaction(async (client) => {
    await repo.upsertResponse(client, reviewId, userId, response);
    await emit(client, 'review.response_posted', 'provider_review', reviewId, [review.customerUserId], { reviewId });
  });
  return repo.findById(reviewId);
}

export async function reportReview(userId: string, reviewId: string, reason: string, details?: string | null) {
  const review = await repo.findById(reviewId);
  if (!review) throw new NotFoundError('Review not found');
  await transaction(async (client) => {
    await repo.insertReport(client, reviewId, userId, reason, details ?? null);
  });
  return { reviewId, reported: true };
}

export async function moderateReview(userId: string, reviewId: string, input: ModerateReviewInput) {
  if (!(await authz.hasPermission(userId, 'review.moderate'))) throw new ForbiddenError('Missing permission: review.moderate');
  const review = await repo.findById(reviewId);
  if (!review) throw new NotFoundError('Review not found');
  await transaction(async (client) => {
    await repo.setStatus(client, reviewId, input.status, userId, input.reason ?? null, review.status);
  });
  return repo.findById(reviewId);
}

export async function getRatingSummary(providerProfileId: string) {
  return repo.getRatingSummary(providerProfileId);
}

export async function listPublishedForProfile(providerProfileId: string, limit = 20, offset = 0) {
  const r = await pool.query(
    `SELECT id FROM provider_reviews WHERE provider_profile_id = $1 AND status = 'published' ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [providerProfileId, limit, offset],
  );
  return r.rows;
}