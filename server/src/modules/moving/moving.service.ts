// Moving & relocation operations service (Task 13.6).
// Builds a moving job FROM an accepted marketplace quotation (contractual
// snapshot) and drives its lifecycle, staff, assessments, scheduling,
// amendments, completion and evidence. Business change + history + outbox share
// one transaction. Reuses provider context, org permissions and the outbox.
import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import type { ProviderContext } from '../provider/provider.types.js';
import type {
  AssignStaffInput,
  CompletionSubmissionInput,
  CreateAssessmentInput,
  CreateMovingJobInput,
  CustomerConfirmationInput,
  MovingProgressInput,
  ProposeAmendmentInput,
  ProposeRescheduleInput,
} from './moving.schemas.js';
import type {
  MovingActor,
  MovingJob,
  MovingJobDetail,
  MovingJobStatus,
  MovingJobScope,
} from './moving.types.js';
import {
  assertTransition,
  checklistTemplateForScope,
  isTerminal,
} from './moving.lifecycle.js';
import * as repo from './moving.repository.js';

async function providerUserId(profileId: string): Promise<string | null> {
  const r = await pool.query<{ user_id: string }>(
    `SELECT user_id FROM specialized_profiles WHERE id = $1`,
    [profileId],
  );
  return r.rows[0]?.user_id ?? null;
}

function actorFor(userId: string, job: MovingJob): MovingActor {
  if (job.customerUserId === userId) return 'customer';
  return 'provider';
}

// ---------------------------------------------------------------------------
// Authorization helpers
// ---------------------------------------------------------------------------
async function loadProviderContext(userId: string, organizationId?: string | null) {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No approved provider profile or organization context');
  return context;
}

// Provider (or active assigned staff) may access a job; `permission` gates
// sensitive operations. The assigned staff user is always allowed for the job.
async function assertProviderAccess(
  context: ProviderContext,
  job: MovingJob,
  permission?: string,
): Promise<void> {
  const isOwnerProfile = context.effectiveProfileIds.includes(job.providerProfileId);
  // The owning profile (individual mover or org manager) always manages its job.
  if (isOwnerProfile) return;
  // Otherwise the user must be the assigned staff or an active assigned staff member.
  const isAssignedStaff = job.assignedStaffUserId === context.userId;
  const isActiveStaff = (
    await pool.query(
      `SELECT 1 FROM moving_job_staff_assignments
        WHERE moving_job_id = $1 AND user_id = $2 AND is_active`,
      [job.id, context.userId],
    )
  ).rowCount;
  if (!isAssignedStaff && !isActiveStaff) {
    throw new ForbiddenError('You are not authorized for this moving job');
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

async function loadJobForCustomer(userId: string, jobId: string): Promise<MovingJob> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  if (job.customerUserId !== userId) throw new ForbiddenError('You may not access this moving job');
  return job;
}

// ---------------------------------------------------------------------------
// Job creation from an accepted quotation
// ---------------------------------------------------------------------------
export async function createJobFromQuotation(
  userId: string,
  input: CreateMovingJobInput,
  organizationId?: string | null,
): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);

  const requestId = await quoteRequestId(input.quotationId);
  const accepted = await repo.findAcceptedQuotation(requestId);
  if (!accepted) throw new ConflictError('Quotation is not accepted');
  if (!context.effectiveProfileIds.includes(accepted.providerProfileId)) {
    throw new ForbiddenError('You may not create a job for this quotation');
  }

  const existing = await repo.findJobByRequestId(requestId);
  if (existing) throw new ConflictError('A moving job already exists for this request');

  // Scope snapshot: request details + provider-supplied logistics.
  const requestRow = await pool.query<{ details: Record<string, unknown>; customer_user_id: string }>(
    `SELECT details, customer_user_id AS "customer_user_id" FROM service_requests WHERE id = $1`,
    [requestId],
  );
  const requestDetails = requestRow.rows[0]?.details ?? {};
  const scope: MovingJobScope = {
    serviceCategories: input.scope?.serviceCategories ?? [],
    capabilities: input.scope?.capabilities ?? [],
    inventory: input.scope?.inventory ?? (requestDetails.notes as string | undefined),
    accessInstructions: input.scope?.accessInstructions,
    notes: input.scope?.notes,
    requestDetails,
  };
  const checklist = Object.fromEntries(
    checklistTemplateForScope(scope.serviceCategories).map((t) => [t.id, false]),
  );

  const jobId = await transaction(async (client) => {
    const created = await repo.insertJob(client, {
      serviceRequestId: requestId,
      quotationId: accepted.id,
      quotationVersion: accepted.versionNumber,
      customerUserId: requestRow.rows[0]!.customer_user_id,
      providerProfileId: accepted.providerProfileId,
      providerOrganisationId: context.activeOrganizationId,
      agreedPrice: accepted.totalAmount,
      currency: accepted.currency,
      scope,
      originLocationId: input.origin?.locationId ?? null,
      destinationLocationId: input.destination?.locationId ?? null,
      originAddress: input.origin?.address ?? null,
      destinationAddress: input.destination?.address ?? null,
      agreedMoveDate: input.agreedMoveDate ?? null,
      agreedWindowStart: input.agreedWindowStart ?? null,
      agreedWindowEnd: input.agreedWindowEnd ?? null,
      checklist,
      tenancyId: input.tenancyId ?? null,
      propertyId: input.propertyId ?? null,
      unitId: input.unitId ?? null,
      createdBy: userId,
    });
    await repo.insertHistory(client, {
      jobId: created.id,
      action: 'confirmed',
      changedBy: userId,
      newStatus: 'confirmed',
      metadata: { quotationId: accepted.id, version: accepted.versionNumber },
    });
    const eventType = 'moving_job.confirmed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [requestRow.rows[0]!.customer_user_id],
      organisationId: context.activeOrganizationId,
      resourceType: 'moving_job',
      resourceId: created.id,
      payload: { jobId: created.id, requestId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
    return created.id;
  });

  const detail = await repo.getJobDetail(jobId);
  return detail!;
}

async function quoteRequestId(quotationId: string): Promise<string> {
  const r = await pool.query<{ service_request_id: string }>(
    `SELECT service_request_id FROM service_quotations WHERE id = $1`,
    [quotationId],
  );
  if (!r.rows[0]) throw new NotFoundError('Quotation not found');
  return r.rows[0].service_request_id;
}

// ---------------------------------------------------------------------------
// Customer
// ---------------------------------------------------------------------------
export async function listCustomerJobs(userId: string, query: { status?: MovingJobStatus; limit: number; offset: number }) {
  return repo.listJobsByCustomer(userId, query);
}

export async function getCustomerJob(userId: string, jobId: string): Promise<MovingJobDetail> {
  await loadJobForCustomer(userId, jobId);
  return (await repo.getJobDetail(jobId))!;
}

export async function cancelJob(userId: string, jobId: string, reason: string): Promise<MovingJobDetail> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  const actor: MovingActor = job.customerUserId === userId ? 'customer' : 'provider';
  if (actor === 'provider') {
    const context = await loadProviderContext(userId);
    await assertProviderAccess(context, job);
  }
  assertTransition(job.status, 'cancelled', actor);
  await transaction(async (client) => {
    await repo.updateJobStatus(client, {
      jobId,
      expectedFrom: job.status,
      toStatus: 'cancelled',
      actorUserId: userId,
      reason,
    });
    const eventType = 'moving_job.cancelled';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [job.customerUserId === userId ? job.providerProfileId : job.customerUserId].filter(Boolean) as string[],
      organisationId: null,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, reason },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function confirmCompletion(userId: string, jobId: string, input: CustomerConfirmationInput): Promise<MovingJobDetail> {
  const job = await loadJobForCustomer(userId, jobId);
  if (job.status !== 'awaiting_customer_confirmation') {
    throw new ConflictError('Job is not awaiting customer confirmation');
  }
  if (!job.completionSubmittedAt) throw new ConflictError('Provider has not submitted completion yet');

  await transaction(async (client) => {
    await repo.recordCustomerConfirmation(client, jobId, { confirm: input.confirm, notes: input.notes ?? null });
    if (input.confirm) {
      await repo.updateJobStatus(client, {
        jobId,
        expectedFrom: job.status,
        toStatus: 'completed',
        actorUserId: userId,
      });
    }
    const eventType = input.confirm ? 'moving_job.completed' : 'moving_job.completion_exception';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [],
      organisationId: null,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, confirm: input.confirm, exception: input.exception ?? null },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
export async function listProviderJobs(userId: string, query: { status?: MovingJobStatus; organizationId?: string; limit: number; offset: number }) {
  const context = await loadProviderContext(userId, query.organizationId);
  return repo.listJobsForProvider(context.effectiveProfileIds, userId, query);
}

export async function getProviderJob(userId: string, jobId: string, organizationId?: string | null): Promise<MovingJobDetail & { canViewLocations: boolean }> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job);
  const detail = (await repo.getJobDetail(jobId))!;
  const canViewLocations = await canViewSensitiveLocations(context, job);
  return { ...detail, canViewLocations };
}

async function canViewSensitiveLocations(context: ProviderContext, job: MovingJob): Promise<boolean> {
  const isOwnerProfile = context.effectiveProfileIds.includes(job.providerProfileId);
  const isAssignedStaff = job.assignedStaffUserId === context.userId;
  const isActiveStaff = (
    await pool.query(
      `SELECT 1 FROM moving_job_staff_assignments WHERE moving_job_id = $1 AND user_id = $2 AND is_active`,
      [job.id, context.userId],
    )
  ).rowCount;
  if (!isOwnerProfile && !isAssignedStaff && !isActiveStaff) return false;
  if (isOwnerProfile || isAssignedStaff) return true;
  return authz.hasPermission(context.userId, 'provider.moving.view_locations');
}

export async function updateProgress(
  userId: string,
  jobId: string,
  input: MovingProgressInput,
  organizationId?: string | null,
): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.update_progress');
  assertTransition(job.status, input.toStatus, 'provider');

  await transaction(async (client) => {
    if (input.checklist) await repo.mergeChecklist(client, jobId, input.checklist);
    await repo.updateJobStatus(client, {
      jobId,
      expectedFrom: job.status,
      toStatus: input.toStatus,
      actorUserId: userId,
      reason: input.reason ?? null,
    });
    const eventType = `moving_job.${input.toStatus}`;
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, status: input.toStatus },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function failJob(userId: string, jobId: string, reason: string, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.update_progress');
  assertTransition(job.status, 'failed', 'provider');
  await transaction(async (client) => {
    await repo.updateJobStatus(client, {
      jobId,
      expectedFrom: job.status,
      toStatus: 'failed',
      actorUserId: userId,
      reason,
    });
    await repo.insertHistory(client, { jobId, action: 'failed', changedBy: userId, newStatus: 'failed', reason });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Staff ----
export async function assignStaff(userId: string, jobId: string, input: AssignStaffInput, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.assign_staff');
  // The staff member must belong to the provider organization (if any).
  if (job.providerOrganisationId) {
    const member = await pool.query(
      `SELECT 1 FROM organisation_members WHERE organisation_id = $1 AND user_id = $2 AND status = 'active'`,
      [job.providerOrganisationId, input.userId],
    );
    if (!member.rowCount) throw new ValidationError('Staff member is not an active organization member');
  }
  await transaction(async (client) => {
    await client.query(
      `UPDATE moving_job_staff_assignments SET is_active = FALSE, revoked_at = NOW(), revoked_by = $2
        WHERE moving_job_id = $1 AND user_id = $3 AND is_active`,
      [jobId, userId, input.userId],
    );
    await client.query(
      `INSERT INTO moving_job_staff_assignments (moving_job_id, user_id, assigned_by, label)
       VALUES ($1,$2,$3,$4)`,
      [jobId, input.userId, userId, input.label ?? null],
    );
    if (!job.assignedStaffUserId || job.assignedStaffUserId !== input.userId) {
      await client.query(`UPDATE moving_jobs SET assigned_staff_user_id = $2 WHERE id = $1`, [jobId, input.userId]);
    }
    await repo.insertHistory(client, { jobId, action: 'staff_assigned', changedBy: userId, metadata: { userId: input.userId } });
    const eventType = 'moving_job.staff_assigned';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}:${input.userId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [input.userId],
      organisationId: job.providerOrganisationId,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, staffUserId: input.userId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Checklist ----
export async function updateChecklist(userId: string, jobId: string, items: Record<string, boolean>, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.update_progress');
  await transaction(async (client) => {
    await repo.mergeChecklist(client, jobId, items);
    await repo.insertHistory(client, { jobId, action: 'checklist_updated', changedBy: userId, metadata: { items } });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Assessments ----
export async function requestAssessment(userId: string, jobId: string, input: CreateAssessmentInput, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.update_progress');
  await transaction(async (client) => {
    const created = await repo.insertAssessment(client, {
      jobId,
      requestedBy: userId,
      proposedAt: input.proposedAt ?? null,
      locationId: input.locationId ?? null,
      locationAddress: input.locationAddress ?? null,
      providerNotes: input.providerNotes ?? null,
    });
    await repo.insertHistory(client, { jobId, action: 'assessment_requested', changedBy: userId, metadata: { assessmentId: created.id } });
    const eventType = 'moving_job.assessment_requested';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${created.id}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, assessmentId: created.id },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function respondAssessment(userId: string, assessmentId: string, accept: boolean, notes: string | undefined): Promise<MovingJobDetail> {
  const assessment = await repo.findAssessment(assessmentId);
  if (!assessment) throw new NotFoundError('Assessment not found');
  const job = await repo.findJobById(assessment.movingJobId);
  if (!job) throw new NotFoundError('Moving job not found');
  if (job.customerUserId !== userId) throw new ForbiddenError('Only the customer may respond to an assessment');
  if (assessment.status !== 'requested') throw new ConflictError('Assessment is not awaiting a response');
  await transaction(async (client) => {
    await repo.updateAssessment(client, assessmentId, {
      status: accept ? 'accepted' : 'declined',
      customerNotes: notes ?? null,
    });
    await repo.insertHistory(client, { jobId: job.id, action: accept ? 'assessment_accepted' : 'assessment_declined', changedBy: userId, metadata: { assessmentId } });
  });
  return (await repo.getJobDetail(job.id))!;
}

export async function completeAssessment(userId: string, assessmentId: string, outcome: string, notes: string | undefined, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const assessment = await repo.findAssessment(assessmentId);
  if (!assessment) throw new NotFoundError('Assessment not found');
  const job = await repo.findJobById(assessment.movingJobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.update_progress');
  if (assessment.status !== 'accepted') throw new ConflictError('Assessment is not accepted');
  await transaction(async (client) => {
    await repo.updateAssessment(client, assessmentId, { status: 'completed', outcome, providerNotes: notes ?? null });
    await repo.insertHistory(client, { jobId: job.id, action: 'assessment_completed', changedBy: userId, metadata: { assessmentId, outcome } });
  });
  return (await repo.getJobDetail(job.id))!;
}

// ---- Rescheduling ----
export async function proposeReschedule(userId: string, jobId: string, input: ProposeRescheduleInput): Promise<MovingJobDetail> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  if (isTerminal(job.status)) throw new ConflictError('Job is closed');
  const isCustomer = job.customerUserId === userId;
  if (!isCustomer) {
    const context = await loadProviderContext(userId);
    await assertProviderAccess(context, job, 'provider.moving.manage_schedule');
  }
  await transaction(async (client) => {
    await repo.insertScheduleChange(client, {
      jobId,
      requestedBy: userId,
      previousDate: job.agreedMoveDate,
      previousWindowStart: job.agreedWindowStart,
      previousWindowEnd: job.agreedWindowEnd,
      proposedDate: input.proposedDate,
      proposedWindowStart: input.proposedWindowStart ?? null,
      proposedWindowEnd: input.proposedWindowEnd ?? null,
      reason: input.reason ?? null,
    });
    await repo.insertHistory(client, { jobId, action: 'reschedule_requested', changedBy: userId, metadata: { proposedDate: input.proposedDate } });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function decideReschedule(userId: string, jobId: string, changeId: string, accept: boolean): Promise<MovingJobDetail> {
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  const change = await repo.findScheduleChange(changeId);
  if (!change || change.movingJobId !== jobId) throw new NotFoundError('Schedule change not found');
  if (change.status !== 'pending') throw new ConflictError('Schedule change already decided');
  // Only the party who did NOT propose may decide.
  const proposerIsCustomer = await isCustomerRequester(changeId);
  if (proposerIsCustomer) {
    if (job.customerUserId === userId) throw new ForbiddenError('Provider must decide a customer-requested change');
    const context = await loadProviderContext(userId);
    await assertProviderAccess(context, job, 'provider.moving.manage_schedule');
  } else {
    if (job.customerUserId !== userId) throw new ForbiddenError('Only the customer may decide a provider-requested change');
  }
  await transaction(async (client) => {
    await repo.resolveScheduleChange(client, changeId, accept, userId);
    await repo.insertHistory(client, { jobId, action: accept ? 'reschedule_accepted' : 'reschedule_rejected', changedBy: userId, metadata: { changeId } });
  });
  return (await repo.getJobDetail(jobId))!;
}

async function isCustomerRequester(changeId: string): Promise<boolean> {
  const job = await pool.query<{ customer_user_id: string }>(
    `SELECT mj.customer_user_id FROM moving_job_schedule_changes sc
       JOIN moving_jobs mj ON mj.id = sc.moving_job_id WHERE sc.id = $1`,
    [changeId],
  );
  const r = await pool.query<{ requested_by: string }>(
    `SELECT requested_by FROM moving_job_schedule_changes WHERE id = $1`,
    [changeId],
  );
  return job.rows[0]?.customer_user_id === r.rows[0]?.requested_by;
}

// ---- Amendments ----
export async function proposeAmendment(userId: string, jobId: string, input: ProposeAmendmentInput, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.propose_changes');
  if (isTerminal(job.status)) throw new ConflictError('Job is closed');
  await transaction(async (client) => {
    await repo.insertAmendment(client, {
      jobId,
      proposedBy: userId,
      reason: input.reason,
      revisedScope: (input.revisedScope ?? {}) as Record<string, unknown>,
      additionalCost: input.additionalCost.toFixed(2),
      currency: job.currency,
    });
    await repo.insertHistory(client, { jobId, action: 'amendment_proposed', changedBy: userId, metadata: { additionalCost: input.additionalCost } });
    const eventType = 'moving_job.amendment_proposed';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, reason: input.reason, additionalCost: input.additionalCost },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export async function decideAmendment(userId: string, jobId: string, amendmentId: string, accept: boolean): Promise<MovingJobDetail> {
  const job = await loadJobForCustomer(userId, jobId);
  const amendment = await repo.findAmendment(amendmentId);
  if (!amendment || amendment.movingJobId !== jobId) throw new NotFoundError('Amendment not found');
  if (amendment.status !== 'pending') throw new ConflictError('Amendment already decided');
  await transaction(async (client) => {
    await repo.resolveAmendment(client, amendmentId, accept, userId);
    await repo.insertHistory(client, {
      jobId,
      action: accept ? 'amendment_accepted' : 'amendment_rejected',
      changedBy: userId,
      metadata: { amendmentId, additionalCost: amendment.additionalCost },
    });
    const eventType = accept ? 'moving_job.amendment_accepted' : 'moving_job.amendment_rejected';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${amendmentId}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [],
      organisationId: job.providerOrganisationId,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId, amendmentId, accept },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

// ---- Completion ----
export async function submitCompletion(userId: string, jobId: string, input: CompletionSubmissionInput, organizationId?: string | null): Promise<MovingJobDetail> {
  const context = await loadProviderContext(userId, organizationId);
  const job = await repo.findJobById(jobId);
  if (!job) throw new NotFoundError('Moving job not found');
  await assertProviderAccess(context, job, 'provider.moving.upload_evidence');
  assertTransition(job.status, 'awaiting_customer_confirmation', 'provider');
  await transaction(async (client) => {
    await repo.submitCompletion(client, jobId, {
      notes: input.notes ?? null,
      outstandingIssue: input.outstandingIssue,
      checklist: input.checklist,
    });
    if (input.evidenceDocumentIds.length > 0) {
      await repo.insertAttachments(client, jobId, input.evidenceDocumentIds, 'completion', userId);
    }
    await repo.updateJobStatus(client, {
      jobId,
      expectedFrom: job.status,
      toStatus: 'awaiting_customer_confirmation',
      actorUserId: userId,
    });
    await repo.insertHistory(client, { jobId, action: 'completion_submitted', changedBy: userId, newStatus: 'awaiting_customer_confirmation' });
    const eventType = 'moving_job.completion_submitted';
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `${eventType}:${jobId}`,
      eventType,
      category: 'operational',
      priority: 'high',
      recipientUserIds: [job.customerUserId],
      organisationId: context.activeOrganizationId,
      resourceType: 'moving_job',
      resourceId: jobId,
      payload: { jobId },
      channels: ['in_app'],
      classification: classifyEventType(eventType),
    });
  });
  return (await repo.getJobDetail(jobId))!;
}

export { actorFor };