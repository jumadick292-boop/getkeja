// Provider reviews controller (Task 13.16).
import type { Request, Response } from 'express';
import { ForbiddenError } from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import type { CreateReviewInput, ModerateReviewInput } from './reviews.schemas.js';
import * as service from './reviews.service.js';

interface AuthenticatedRequest extends Request { user?: AuthUser; }

function assertAuth(req: AuthenticatedRequest): string {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

function orgId(req: AuthenticatedRequest): string | null {
  const h = req.headers['x-organization-id'];
  return typeof h === 'string' && h.length > 0 ? h : null;
}

export async function submitReview(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as CreateReviewInput;
  res.status(201).json({ success: true, data: await service.submitReview(userId, String(req.params.domain), String(req.params.resourceId), body) });
}

export async function listProviderReviews(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as { status?: string; limit?: number; offset?: number };
  const result = await service.listProviderReviews(userId, orgId(req), q.status, q.limit ?? 20, q.offset ?? 0);
  res.json({ success: true, data: result.rows, pagination: { total: result.total, limit: q.limit ?? 20, offset: q.offset ?? 0 } });
}

export async function listCustomerReviews(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const q = req.query as { limit?: number; offset?: number };
  res.json({ success: true, data: await service.listCustomerReviews(userId, q.limit ?? 20, q.offset ?? 0) });
}

export async function getReview(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  res.json({ success: true, data: await service.getReview(userId, String(req.params.reviewId)) });
}

export async function respondToReview(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { response: string };
  res.json({ success: true, data: await service.respondToReview(userId, orgId(req), String(req.params.reviewId), body.response) });
}

export async function reportReview(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as { reason: string; details?: string };
  res.json({ success: true, data: await service.reportReview(userId, String(req.params.reviewId), body.reason, body.details ?? null) });
}

export async function moderateReview(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const body = req.body as ModerateReviewInput;
  res.json({ success: true, data: await service.moderateReview(userId, String(req.params.reviewId), body) });
}

export async function getRatingSummary(req: AuthenticatedRequest, res: Response) {
  res.json({ success: true, data: await service.getRatingSummary(String(req.params.providerProfileId)) });
}