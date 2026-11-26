// Finishing & Building Services service (Task 13.15).
// Builds a finishing job FROM an accepted marketplace quotation (immutable
// snapshot) and drives site inspection/measurement, work plans & checklists,
// materials/finish records, quality inspections & corrective work, amendments,
// scheduling, staff assignment, progress, before/after evidence, exceptions,
// handover and customer confirmation. Business change + history + outbox share
// one transaction. Reuses provider context, org permissions, scheduling, outbox.
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import { enqueueOutboxEventTransactional } from '../auth/transactional-outbox.service.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type {
  CreateFinishingJobInput,
  FinishingAssessmentInput,
  FinishingAttachmentInput,
  FinishingInspectionInput,
  FinishingMaterialInput,
  FinishingPlanInput,
  FinishingProgressInput,
  ProposeFinishingAmendmentInput,
} from './finishing-operations.schemas.js';
import type {
  FinishingActor,
  FinishingJob,
  FinishingJobDetail,
  FinishingOperationStatus,
} from './finishing-operations.types.js';
import { assertFinishingTransition } from './finishing-operations.lifecycle.js';
import * as repo from './finishing-operations.repository.js';

const JOB_EVENT_PREFIX = 'finishing_job';

function actorFor(userId: string, job: FinishingJob): FinishingActor {
  return job.customerUserId === userId ? 'customer' : 'provider';
}

async function loadProviderContext(userId: string, organizationId?: string | null): Promise<ProviderContext> {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return context;
}

async function assertProviderAccess(context: ProviderContext, job: FinishingJob, permission?: string): Promise<void> {
  if (context.effectiveProfileIds.includes(job.providerProfileId)) return;
  const isAssigned = job.assignedStaffUserId === context.userId;
  const isActiveStaff = (await pool.query(
    `SELECT 1 FROM finishing_staff_assignments WHERE job_id = $1 AND user_id = $2 AND is_active`,
    [job.id, context.userId],
  )).rowCount;
  if (!isAssigned && !isActiveStaff) {
    throw new ForbiddenError('You are not authorized for this finishing job');
  }
  if (permission) {
    const roleIds = job.providerOrganisationId
      ? await authz.getUserOrganizationRoleIds(context.userId, job.providerOrganisationId)
      : [];
    if (roleIds.some((r) => ['organization_owner', 'organization_admin'].includes(r))) return;
    if (!(await authz.hasPermission(context.userId, permission))) {
      throw new ForbiddenError(`Missing permission: ${permission}`);
    }
  }
}

async function loadJobForCustomer(userId: string, jobId: string): Promise<FinishingJob> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  if (job.customerUserId !== userId) throw new ForbiddenError('You may not access this finishing job');
  return job;
}

// Customer-facing projection: internal provider notes are never exposed.
function toCustomerDetail(detail: FinishingJobDetail): FinishingJobDetail {
  return {
    ...detail,
    assessments: detail.assessments.map((a) => ({ ...a, internalNotes: null })),
    materials: detail.materials.map((m) => ({ ...m, notes: m.customerVisible ? m.notes : null })),
    inspections: detail.inspections.map((t) => ({ ...t, details: t.customerVisible ? t.details : null, correctiveWork: t.customerVisible ? t.correctiveWork : null })),
  };
}

async function quoteRequestId(quotationId: string): Promise<string> {
  const r = await pool.query<{ service_request_id: string }>(
    `SELECT service_request_id FROM service_quotations WHERE id = $1`, [quotationId]);
  if (!r.rows[0]) throw new NotFoundError('Quotation not found');
  return r.rows[0].service_request_id;
}

async function emitJobEvent(client: Parameters<Parameters<typeof transaction>[0]>[0], jobId: string, eventType: string, recipientUserIds: string[], organisationId: string | null, payload: Record<string, unknown>): Promise<void> {
  await enqueueOutboxEventTransactional(client, {
    idempotencyKey: `${eventType}:${jobId}`,
    eventType,
    category: 'operational',
    priority: 'high',
    recipientUserIds,
    organisationId,
    resourceType: 'finishing_job',
    resourceId: jobId,
    payload,
    channels: ['in_app'],
    classification: 'critical',
  });
}

async function changeStatus(
  userId: string,
  job: FinishingJob,
  to: FinishingOperationStatus,
  reason?: string | null,
  extra?: Record<string, unknown>,
): Promise<FinishingJobDetail> {
  const actor = actorFor(userId, job);
  assertFinishingTransition(job.status, to, actor);
  const eventType = `${JOB_EVENT_PREFIX}.${to}`;
  const recipients = [job.customerUserId];
  await transaction(async (client) => {
    await repo.updateStatus(job.id, to, extra);
    await repo.insertHistory(client, {
      jobId: job.id, action: to, changedBy: userId,
      previousStatus: job.status, newStatus: to, changeReason: reason ?? null,
    });
    await emitJobEvent(client, job.id, eventType, recipients, job.providerOrganisationId, { from: job.status, reason: reason ?? null });
  });
  const updated = await repo.findJobById(job.id);
  return repo.getJobDetail(updated!);
}

// ---------------------------------------------------------------------------
// Job creation from an accepted quotation (idempotent, concurrency-safe).
// ---------------------------------------------------------------------------
export async function createJobFromQuotation(
  userId: string,
  input: CreateFinishingJobInput,
  organizationId?: string | null,
): Promise<FinishingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const requestId = await quoteRequestId(input.quotationId);
  const accepted = await repo.findAcceptedQuotation(requestId);
  if (!accepted) throw new ConflictError('Quotation is not accepted');
  if (!context.effectiveProfileIds.includes(accepted.providerProfileId)) {
    throw new ForbiddenError('You may not create a job for this quotation');
  }
  const existing = await repo.findJobByRequestId(requestId);
  if (existing) return repo.getJobDetail(existing);

  const reqRow = await pool.query<{ details: Record<string, unknown>; customer_user_id: string; category_id: string; domain: string }>(
    `SELECT details, customer_user_id AS "customer_user_id", category_id, domain::text AS domain FROM service_requests WHERE id = $1`,
    [requestId],
  );
  if (!reqRow.rows[0]) throw new NotFoundError('Service request not found');
  const req = reqRow.rows[0];
  const scope = { ...(req.details ?? {}), ...(input.scope ?? {}) };

  const created = await transaction(async (client) => {
    await client.query(`SELECT id FROM service_requests WHERE id = $1 FOR UPDATE`, [requestId]);
    const dup = await repo.findJobByRequestId(requestId);
    if (dup) return dup;
    const row = await repo.insertJob(client, {
      serviceRequestId: requestId,
      quotationId: accepted.id,
      quotationVersion: accepted.versionNumber,
      customerUserId: req.customer_user_id,
      providerProfileId: accepted.providerProfileId,
      providerOrganisationId: context.activeOrganizationId,
      categoryId: req.category_id,
      domain: req.domain,
      propertyId: input.propertyId ?? null,
      unitId: input.unitId ?? null,
      tenancyId: input.tenancyId ?? null,
      serviceAddress: input.serviceAddress ?? null,
      agreedPrice: accepted.totalAmount,
      currency: accepted.currency,
      scope,
      assessmentRequired: input.assessmentRequired ?? true,
      createdBy: userId,
    });
    await repo.insertHistory(client, {
      jobId: row.id, action: 'confirmed', changedBy: userId, newStatus: 'confirmed',
      metadata: { quotationId: accepted.id, version: accepted.versionNumber },
    });
    await emitJobEvent(client, row.id, `${JOB_EVENT_PREFIX}.confirmed`, [req.customer_user_id], context.activeOrganizationId, { quotationId: accepted.id });
    return row;
  });
  const job = await repo.findJobById(created.id);
  return repo.getJobDetail(job!);
}

// ---------------------------------------------------------------------------
// Customer operations
// ---------------------------------------------------------------------------
export async function listCustomerJobs(userId: string, q: { status?: string; categoryId?: string; limit: number; offset: number }) {
  return repo.listJobs({ customerUserId: userId, status: q.status, categoryId: q.categoryId, limit: q.limit, offset: q.offset });
}

export async function getCustomerJob(userId: string, jobId: string): Promise<FinishingJobDetail> {
  const job = await loadJobForCustomer(userId, jobId);
  return toCustomerDetail(await repo.getJobDetail(job));
}

export async function cancelJob(userId: string, jobId: string, reason?: string | null) {
  const job = await loadJobForCustomer(userId, jobId);
  return toCustomerDetail(await changeStatus(userId, job, 'cancelled', reason, { cancelled_at: new Date().toISOString(), cancellation_reason: reason ?? null }));
}

export async function confirmCompletion(userId: string, jobId: string, confirm: boolean, notes?: string | null) {
  const job = await loadJobForCustomer(userId, jobId);
  if (job.status !== 'completed_pending_confirmation') {
    throw new ConflictError('Job is not awaiting confirmation');
  }
  if (confirm) return toCustomerDetail(await changeStatus(userId, job, 'completed', notes, { customer_confirmation_status: 'confirmed', customer_confirmation_notes: notes ?? null, customer_confirmation_at: new Date().toISOString() }));
  return toCustomerDetail(await changeStatus(userId, job, 'exception', notes, { customer_confirmation_status: 'disputed', customer_confirmation_notes: notes ?? null, customer_confirmation_at: new Date().toISOString() }));
}

export async function reportException(userId: string, jobId: string, type: string, description: string) {
  const job = await loadJobForCustomer(userId, jobId);
  await transaction(async (client) => {
    await repo.insertException(client, { jobId: job.id, reportedBy: userId, type, description });
    await repo.insertHistory(client, { jobId: job.id, action: 'exception_reported', changedBy: userId, newStatus: 'exception' });
  });
  return toCustomerDetail(await repo.getJobDetail(job));
}

export async function decideAmendment(userId: string, jobId: string, amendmentId: string, decision: 'approve' | 'reject') {
  const job = await loadJobForCustomer(userId, jobId);
  await transaction(async (client) => {
    await repo.decideAmendment(jobId, amendmentId, decision === 'approve' ? 'approved' : 'rejected', userId);
    await repo.insertHistory(client, { jobId, action: `amendment_${decision}`, changedBy: userId });
  });
  return toCustomerDetail(await repo.getJobDetail(job));
}

export async function decideMaterial(userId: string, jobId: string, materialId: string, decision: 'approve' | 'reject') {
  const job = await loadJobForCustomer(userId, jobId);
  await transaction(async (client) => {
    await repo.setMaterialApproval(jobId, materialId, decision === 'approve' ? 'approved' : 'rejected');
    await repo.insertHistory(client, { jobId, action: `material_${decision}`, changedBy: userId });
  });
  return toCustomerDetail(await repo.getJobDetail(job));
}

// ---------------------------------------------------------------------------
// Provider operations
// ---------------------------------------------------------------------------
export async function listProviderJobs(userId: string, organizationId: string | null | undefined, q: { status?: string; categoryId?: string; limit: number; offset: number }) {
  const context = await loadProviderContext(userId, organizationId);
  return repo.listProviderJobs({ profileIds: context.effectiveProfileIds, staffUserId: userId, status: q.status, categoryId: q.categoryId, limit: q.limit, offset: q.offset });
}

export async function getProviderJob(userId: string, organizationId: string | null | undefined, jobId: string, permission = 'provider.finishing.view') {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, permission);
  return repo.getJobDetail(job);
}

export async function updateProgress(userId: string, organizationId: string | null | undefined, jobId: string, input: FinishingProgressInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.update_progress');
  const extra: Record<string, unknown> = {};
  if (input.to === 'completed_pending_confirmation') {
    extra.completion_submitted_at = new Date().toISOString();
  }
  return changeStatus(userId, job, input.to, input.reason, extra);
}

export async function failJob(userId: string, organizationId: string | null | undefined, jobId: string, reason: string) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.update_progress');
  return changeStatus(userId, job, 'failed', reason, { failed_at: new Date().toISOString(), failure_reason: reason });
}

export async function providerCancelJob(userId: string, organizationId: string | null | undefined, jobId: string, reason?: string | null) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.update_progress');
  return changeStatus(userId, job, 'cancelled', reason, { cancelled_at: new Date().toISOString(), cancellation_reason: reason ?? null });
}

export async function recordAssessment(userId: string, organizationId: string | null | undefined, jobId: string, input: FinishingAssessmentInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.manage_assessments');
  await transaction(async (client) => {
    await repo.insertAssessment(client, {
      jobId: job.id,
      assessorUserId: input.assessorUserId ?? null,
      status: input.complete ? 'completed' : 'scheduled',
      scheduledAt: input.scheduledAt ?? null,
      findings: input.findings ?? null,
      measurements: input.measurements ?? null,
      siteReadiness: input.siteReadiness ?? null,
      recommendedScope: input.recommendedScope ?? null,
      estimatedDurationMinutes: input.estimatedDurationMinutes ?? null,
      safetyConcerns: input.safetyConcerns ?? null,
      customerVisibleReport: input.customerVisibleReport ?? null,
      internalNotes: input.internalNotes ?? null,
      photoDocumentIds: input.photoDocumentIds ?? [],
      createdBy: userId,
    });
    await repo.insertHistory(client, { jobId: job.id, action: 'assessment_recorded', changedBy: userId });
  });
  return repo.getJobDetail(job);
}

export async function createPlan(userId: string, organizationId: string | null | undefined, jobId: string, input: FinishingPlanInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.manage_plans');
  await transaction(async (client) => {
    await repo.insertPlan(client, {
      jobId: job.id, summary: input.summary, steps: input.steps ?? [],
      deliverables: input.deliverables ?? null, scheduledAt: input.scheduledAt ?? null, createdBy: userId,
    });
    await repo.insertHistory(client, { jobId: job.id, action: 'plan_created', changedBy: userId });
  });
  return repo.getJobDetail(job);
}

export async function addMaterial(userId: string, organizationId: string | null | undefined, jobId: string, input: FinishingMaterialInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.propose_changes');
  await transaction(async (client) => {
    await repo.insertMaterial(client, {
      jobId: job.id, description: input.description,
      category: input.category ?? 'material',
      quantity: String(input.quantity ?? 1), unit: input.unit ?? 'unit',
      finishOrSpec: input.finishOrSpec ?? null, suppliedBy: input.suppliedBy ?? 'provider',
      proposedCost: input.proposedCost != null ? String(input.proposedCost) : null,
      installStatus: input.installStatus ?? 'pending',
      customerVisible: input.customerVisible ?? true,
      notes: input.notes ?? null, createdBy: userId,
    });
    await repo.insertHistory(client, { jobId: job.id, action: 'material_proposed', changedBy: userId });
  });
  return repo.getJobDetail(job);
}

export async function decideMaterialProvider(userId: string, organizationId: string | null | undefined, jobId: string, materialId: string, decision: 'approve' | 'reject') {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.propose_changes');
  await transaction(async (client) => {
    await repo.setMaterialApproval(jobId, materialId, decision === 'approve' ? 'approved' : 'rejected');
    await repo.insertHistory(client, { jobId, action: `material_${decision}`, changedBy: userId });
  });
  return repo.getJobDetail(job);
}

export async function recordInspection(userId: string, organizationId: string | null | undefined, jobId: string, input: FinishingInspectionInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.update_progress');
  await transaction(async (client) => {
    await repo.insertInspection(client, {
      jobId: job.id, name: input.name, outcome: input.outcome ?? 'pending',
      details: input.details ?? null, correctiveWork: input.correctiveWork ?? null,
      customerVisible: input.customerVisible ?? true, inspectedBy: userId, createdBy: userId,
    });
    await repo.insertHistory(client, { jobId: job.id, action: 'inspection_recorded', changedBy: userId });
  });
  return repo.getJobDetail(job);
}

export async function addAttachment(userId: string, organizationId: string | null | undefined, jobId: string, input: FinishingAttachmentInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.upload_evidence');
  await transaction(async (client) => {
    await repo.insertAttachment(client, { jobId: job.id, documentId: input.documentId, kind: input.kind ?? 'evidence', uploadedBy: userId });
    await repo.insertHistory(client, { jobId: job.id, action: 'evidence_uploaded', changedBy: userId, metadata: { kind: input.kind ?? 'evidence' } });
  });
  return repo.getJobDetail(job);
}

export async function assignStaff(userId: string, organizationId: string | null | undefined, jobId: string, staffUserId: string, label?: string | null) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.assign_staff');
  if (job.providerOrganisationId) {
    const member = await pool.query(
      `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2 AND status = 'active'`,
      [job.providerOrganisationId, staffUserId]);
    if (!member.rowCount) throw new ValidationError('Staff user is not an active organization member');
  }
  await transaction(async (client) => {
    await repo.insertStaff(client, { jobId: job.id, userId: staffUserId, label: label ?? null, assignedBy: userId });
    await repo.setAssignedStaff(job.id, staffUserId);
    await repo.insertHistory(client, { jobId: job.id, action: 'staff_assigned', changedBy: userId, metadata: { staffUserId } });
  });
  return repo.getJobDetail(job);
}

export async function revokeStaff(userId: string, organizationId: string | null | undefined, jobId: string, staffUserId: string) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.assign_staff');
  await transaction(async (client) => {
    await repo.revokeStaff(job.id, staffUserId, userId);
    if (job.assignedStaffUserId === staffUserId) await repo.setAssignedStaff(job.id, null);
    await repo.insertHistory(client, { jobId: job.id, action: 'staff_revoked', changedBy: userId, metadata: { staffUserId } });
  });
  return repo.getJobDetail(job);
}

export async function proposeAmendment(userId: string, organizationId: string | null | undefined, jobId: string, input: ProposeFinishingAmendmentInput) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.propose_changes');
  const currency = input.currency ?? job.currency;
  const additional = input.additionalCost != null ? String(input.additionalCost) : '0';
  await transaction(async (client) => {
    await repo.insertAmendment(client, {
      jobId: job.id, proposedBy: userId, reason: input.reason,
      revisedScope: input.revisedScope ?? {}, additionalCost: additional, currency,
    });
    await repo.insertHistory(client, { jobId: job.id, action: 'amendment_proposed', changedBy: userId });
  });
  return repo.getJobDetail(job);
}

export async function submitCompletion(userId: string, organizationId: string | null | undefined, jobId: string, notes?: string | null) {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Finishing job not found');
  await assertProviderAccess(context, job, 'provider.finishing.update_progress');
  const extra = { completion_notes: notes ?? null, completion_submitted_at: new Date().toISOString(), customer_confirmation_status: 'pending' };
  return changeStatus(userId, job, 'completed_pending_confirmation', notes, extra);
}