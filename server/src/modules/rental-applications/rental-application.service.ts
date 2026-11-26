// Rental application lifecycle service — the authoritative orchestration layer.
//
// Responsibilities:
//  - Create draft/submitted applications with eligibility + duplicate checks.
//  - Apply validated status transitions with actor authorization, writing
//    history (via the DB trigger) and emitting transactional notifications.
//  - Approve an application and hand off to idempotent tenant onboarding.
//  - Manage private internal notes and applicant-visible information requests.
//  - Secure application documents (upload metadata + private download).
//
// The database is the authority for state; the pure state machine in
// rental-application.lifecycle.ts is the authority for legal transitions.

import { pool } from '../../db/pool.js';
import { transaction } from '../../db/tx.js';
import type { PoolClient } from 'pg';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '../../shared/errors.js';
import { NotificationService } from '../auth/notification.service.js';
import {
  type OutboxEventInput,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import {
  type ActorKind,
  type ApplicationStatus,
  type LifecycleAction,
  isApplicationStatus,
  resolveTransition,
} from './rental-application.lifecycle.js';
import {
  type ApplicationRow,
  type InboxFilters,
  type InsertApplicationData,
  addApplicationNote,
  findApplication,
  findApplicationDocument,
  getManagerScope,
  hasActiveApplication,
  hasCompetingApproved,
  insertApplication,
  insertApplicationDocument,
  listApplicationDocuments,
  listApplicationHistory,
  listApplicationNotes,
  listManagedApplications,
} from './rental-application.repository.js';
import { initiateOnboarding } from './rental-onboarding.service.js';

const notifications = new NotificationService();

// ---------------------------------------------------------------------------
// Eligibility
// ---------------------------------------------------------------------------

async function assertEligibleProperty(
  client: PoolClient | typeof pool,
  propertyId: string,
  listingId?: string | null,
): Promise<void> {
  if (listingId) {
    const lr = await client.query<{ property_id: string; status: string }>(
      `SELECT property_id, status FROM property_listings WHERE id = $1`,
      [listingId],
    );
    const row = lr.rows[0];
    if (!row) throw new NotFoundError('Listing not found');
    if (row.status !== 'published') throw new ConflictError('Listing is not available');
    return;
  }
  const eligible = await client.query(
    `SELECT 1 FROM property_listings WHERE property_id = $1 AND status = 'published' LIMIT 1`,
    [propertyId],
  );
  if (!eligible.rows[0]) throw new ConflictError('Property is not currently listed');
}

// A unit that cannot receive a new application.
const UNAVAILABLE_UNIT_STATUSES = new Set(['occupied', 'unavailable', 'under_maintenance']);

async function assertUnitAvailable(
  client: PoolClient | typeof pool,
  unitId: string | null,
): Promise<void> {
  if (!unitId) return;
  const unit = await client.query<{ status: string }>(
    `SELECT status FROM units WHERE id = $1`,
    [unitId],
  );
  if (!unit.rows[0]) throw new NotFoundError('Unit not found');
  if (UNAVAILABLE_UNIT_STATUSES.has(unit.rows[0]!.status)) {
    throw new ConflictError('This unit is not available to receive applications');
  }
}

// ---------------------------------------------------------------------------
// Notifications (transactional outbox for critical events, best-effort post-commit otherwise)
// ---------------------------------------------------------------------------

async function notifyStakeholders(
  application: Pick<ApplicationRow, 'id' | 'propertyId' | 'userId'>,
  eventType: string,
  payload: Record<string, unknown>,
  opts?: { excludeUserId?: string; applicantOnly?: boolean; managersOnly?: boolean },
): Promise<void> {
  try {
    const recipients = new Set<string>();
    if (!opts?.managersOnly && application.userId) recipients.add(application.userId);

    if (!opts?.applicantOnly) {
      const owners = await pool.query<{ user_id: string }>(
        `SELECT user_id FROM property_ownerships
          WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
            AND (effective_to IS NULL OR effective_to > NOW())`,
        [application.propertyId],
      );
      owners.rows.forEach((r) => recipients.add(r.user_id));

      const managers = await pool.query<{ user_id: string }>(
        `SELECT user_id FROM property_assignments
          WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
            AND assignment_type IN ('property_manager','letting_agent')
            AND (effective_to IS NULL OR effective_to > NOW())`,
        [application.propertyId],
      );
      managers.rows.forEach((r) => recipients.add(r.user_id));
    }

    if (opts?.excludeUserId) recipients.delete(opts.excludeUserId);
    if (recipients.size === 0) return;

    await notifications.createOutboxEvent({
      idempotencyKey: `${eventType}:${application.id}`,
      eventType,
      category: 'operational',
      priority: 'normal',
      recipientUserIds: [...recipients],
      organisationId: null,
      resourceType: 'rental_application',
      resourceId: application.id,
      payload,
      channels: ['in_app', 'email'],
    });
  } catch (err) {
    console.error('Notification outbox persistence failed:', err instanceof Error ? err.message : err);
  }
}

/**
 * Persist an outbox event within the same transaction as a critical
 * business state change. If this throws, the caller's transaction rolls
 * back and the state change is never persisted without its notification.
 */
async function notifyStakeholdersTransactional(
  client: PoolClient,
  application: Pick<ApplicationRow, 'id' | 'propertyId' | 'userId'>,
  eventType: string,
  payload: Record<string, unknown>,
  opts?: { excludeUserId?: string; applicantOnly?: boolean; managersOnly?: boolean },
): Promise<void> {
  const recipients = new Set<string>();
  if (!opts?.managersOnly && application.userId) recipients.add(application.userId);

  if (!opts?.applicantOnly) {
    const owners = await client.query<{ user_id: string }>(
      `SELECT user_id FROM property_ownerships
        WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
          AND (effective_to IS NULL OR effective_to > NOW())`,
      [application.propertyId],
    );
    owners.rows.forEach((r) => recipients.add(r.user_id));

    const managers = await client.query<{ user_id: string }>(
      `SELECT user_id FROM property_assignments
        WHERE property_id = $1 AND status = 'active' AND user_id IS NOT NULL
          AND assignment_type IN ('property_manager','letting_agent')
          AND (effective_to IS NULL OR effective_to > NOW())`,
      [application.propertyId],
    );
    managers.rows.forEach((r) => recipients.add(r.user_id));
  }

  if (opts?.excludeUserId) recipients.delete(opts.excludeUserId);
  if (recipients.size === 0) return;

  const input: OutboxEventInput = {
    idempotencyKey: `${eventType}:${application.id}`,
    eventType,
    category: 'operational',
    priority: 'normal',
    recipientUserIds: [...recipients],
    organisationId: null,
    resourceType: 'rental_application',
    resourceId: application.id,
    payload,
    channels: ['in_app', 'email'],
    classification: classifyEventType(eventType),
  };

  await notifications.createOutboxEventTransactional(client, input);
}

// ---------------------------------------------------------------------------
// Create (draft / submit)
// ---------------------------------------------------------------------------

export interface CreateApplicationInput {
  propertyId: string;
  listingId?: string | null;
  unitId?: string | null;
  preferredStartDate?: string | null;
  preferredEndDate?: string | null;
  proposedRentAmount?: number | null;
  employerName?: string | null;
  employerContact?: string | null;
  monthlyIncome?: number | null;
  previousLandlordName?: string | null;
  previousLandlordContact?: string | null;
  guarantorName?: string | null;
  guarantorEmail?: string | null;
  guarantorPhone?: string | null;
  guarantorRelationship?: string | null;
}

async function loadContact(userId: string): Promise<{ name: string; email: string; phone: string }> {
  const result = await pool.query<{ name: string | null; email: string | null; phone_number: string | null }>(
    `SELECT u.name, u.email, up.phone_number
       FROM users u LEFT JOIN user_profiles up ON up.user_id = u.id
      WHERE u.id = $1`,
    [userId],
  );
  const row = result.rows[0];
  if (!row?.email) throw new ValidationError('A verified email is required to apply');
  return {
    name: row.name || row.email,
    email: row.email,
    phone: row.phone_number || '',
  };
}

/**
 * Create a draft or submitted application. Race-safe duplicate prevention uses
 * a transaction-scoped advisory lock keyed on the applicant + property + unit.
 */
export async function createApplication(
  userId: string,
  input: CreateApplicationInput,
  asDraft: boolean,
): Promise<ApplicationRow> {
  const contact = await loadContact(userId);

  return transaction(async (client) => {
    // Serialise concurrent submissions for the same opportunity.
    const lockKey = `app:${userId}:${input.propertyId}:${input.unitId ?? 'none'}`;
    await client.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [lockKey]);

    // Resolve and validate the property/listing (eligibility).
    let propertyId = input.propertyId;
    if (input.listingId) {
      const lr = await client.query<{ property_id: string; status: string }>(
        `SELECT property_id, status FROM property_listings WHERE id = $1`,
        [input.listingId],
      );
      const row = lr.rows[0];
      if (!row) throw new NotFoundError('Listing not found');
      if (row.status !== 'published') throw new ConflictError('Listing is not available');
      propertyId = row.property_id;
    } else {
      const eligible = await client.query(
        `SELECT 1 FROM property_listings WHERE property_id = $1 AND status = 'published' LIMIT 1`,
        [input.propertyId],
      );
      if (!eligible.rows[0]) throw new ConflictError('Property is not currently listed');
    }

    if (input.unitId) {
      const unit = await client.query<{ property_id: string; status: string }>(
        `SELECT property_id, status FROM units WHERE id = $1`,
        [input.unitId],
      );
      if (!unit.rows[0]) throw new NotFoundError('Unit not found');
      if (unit.rows[0]!.property_id !== propertyId) {
        throw new ValidationError('Unit does not belong to the selected property');
      }
      if (UNAVAILABLE_UNIT_STATUSES.has(unit.rows[0]!.status)) {
        throw new ConflictError('This unit is not available to receive applications');
      }
    }

    // Duplicate active application prevention (only for real submissions).
    if (!asDraft && (await hasActiveApplication(client, userId, propertyId, input.unitId ?? null))) {
      throw new ConflictError('You already have an active application for this property/unit');
    }

    const data: InsertApplicationData = {
      propertyId,
      unitId: input.unitId ?? null,
      userId,
      applicantName: contact.name,
      applicantEmail: contact.email,
      applicantPhone: contact.phone,
      status: asDraft ? 'draft' : 'submitted',
      preferredStartDate: input.preferredStartDate ? new Date(input.preferredStartDate) : null,
      preferredEndDate: input.preferredEndDate ? new Date(input.preferredEndDate) : null,
      proposedRentAmount: input.proposedRentAmount ?? null,
      employerName: input.employerName ?? null,
      employerContact: input.employerContact ?? null,
      monthlyIncome: input.monthlyIncome ?? null,
      previousLandlordName: input.previousLandlordName ?? null,
      previousLandlordContact: input.previousLandlordContact ?? null,
      guarantorName: input.guarantorName ?? null,
      guarantorEmail: input.guarantorEmail ?? null,
      guarantorPhone: input.guarantorPhone ?? null,
      guarantorRelationship: input.guarantorRelationship ?? null,
    };

    const application = await insertApplication(client, data);

    if (!asDraft) {
      // Critical: persisted atomically with the application insert. If the
      // outbox insert fails the transaction rolls back and no orphaned,
      // un-notified application is left behind.
      await notifyStakeholdersTransactional(
        client,
        application,
        'application.submitted',
        { applicationId: application.id, propertyId: application.propertyId },
        { applicantOnly: false },
      );
    }
    return application;
  });
}

// ---------------------------------------------------------------------------
// Transition (core)
// ---------------------------------------------------------------------------

export interface TransitionInput {
  applicationId: string;
  actorId: string;
  actorKind: ActorKind;
  action: LifecycleAction;
  reason?: string | null;
  /** Manager-supplied approval terms. */
  terms?: {
    approvedRentAmount?: number;
    approvedDepositAmount?: number;
    approvedStartDate?: string;
    approvedEndDate?: string;
  };
}

export interface TransitionResult {
  application: ApplicationRow;
  onboarding?: {
    tenancyId: string;
    tenantId: string;
    unitId: string;
    alreadyOnboarded: boolean;
  };
  onboardingError?: string;
}

// Map lifecycle actions to notification event types. Critical events are
// persisted atomically with the state change (see below); best-effort events
// are emitted post-commit.
const TRANSITION_EVENT_MAP: Partial<Record<LifecycleAction, string>> = {
  submit: 'application.submitted',
  start_review: 'application.under_review',
  request_information: 'application.information_requested',
  resubmit: 'application.resubmitted',
  shortlist: 'application.shortlisted',
  send_proposal: 'application.proposal_sent',
  start_negotiation: 'application.negotiation_started',
  reject: 'application.rejected',
  withdraw: 'application.withdrawn',
  cancel: 'application.cancelled',
  approve: 'application.approved',
};

export async function transitionApplication(input: TransitionInput): Promise<TransitionResult> {
  const { applicationId, actorId, actorKind, action } = input;

  // The notification event type for this transition (if any).
  const eventType = TRANSITION_EVENT_MAP[action];
  // Critical events must be persisted atomically with the state change.
  const isCritical = eventType ? classifyEventType(eventType) === 'critical' : false;

  const application = await transaction(async (client) => {
    const app = await findApplication(client, applicationId, true);
    if (!app) throw new NotFoundError('Application not found');

    // Authorize the actor for this application.
    if (actorKind === 'applicant') {
      if (app.userId !== actorId) throw new ForbiddenError('You can only act on your own application');
    } else if (actorKind === 'manager') {
      const scope = await getManagerScope(client, actorId, app);
      if (!scope.isManager) {
        throw new ForbiddenError('You are not authorized to manage this application');
      }
    }

    const resolution = resolveTransition(app.status as ApplicationStatus, action, actorKind);
    if (!resolution.ok || !resolution.to) {
      throw new ConflictError(resolution.reason ?? 'Invalid application transition');
    }
    const toStatus = resolution.to;

    // Approval requires the unit to still be available and uncontested.
    if (action === 'approve') {
      if (app.unitId) {
        await client.query(`SELECT 1 FROM units WHERE id = $1 FOR UPDATE`, [app.unitId]);
        const unit = await client.query<{ status: string }>(
          `SELECT status FROM units WHERE id = $1`,
          [app.unitId],
        );
        if (unit.rows[0]?.status === 'occupied') {
          throw new ConflictError('This unit is no longer available');
        }
        if (await hasCompetingApproved(client, app.unitId, app.id)) {
          throw new ConflictError('Another application is already approved for this unit');
        }
      }
    }

    // Build the update set. `updated_by` drives the history trigger attribution.
    const fields: string[] = ['status = $1::application_status', 'updated_by = $2', 'updated_at = NOW()'];
    const values: unknown[] = [toStatus, actorId];
    let i = 3;

    if (action === 'reject') {
      fields.push(`rejection_reason = $${i++}`);
      values.push(input.reason ?? null);
    }
    if (action === 'request_information' || action === 'start_review') {
      fields.push(`reviewed_by = $${i++}`, `reviewed_at = NOW()`);
      values.push(actorId);
    }
    if (action === 'approve') {
      fields.push(`approved_by = $${i++}`, `approved_at = NOW()`);
      values.push(actorId);
      if (input.terms?.approvedRentAmount !== undefined) {
        fields.push(`approved_rent_amount = $${i++}`);
        values.push(input.terms.approvedRentAmount);
      }
      if (input.terms?.approvedDepositAmount !== undefined) {
        fields.push(`approved_deposit_amount = $${i++}`);
        values.push(input.terms.approvedDepositAmount);
      }
      if (input.terms?.approvedStartDate) {
        fields.push(`approved_start_date = $${i++}`);
        values.push(new Date(input.terms.approvedStartDate));
      }
      if (input.terms?.approvedEndDate) {
        fields.push(`approved_end_date = $${i++}`);
        values.push(new Date(input.terms.approvedEndDate));
      }
    }

    values.push(applicationId);
    const updated = await client.query<ApplicationRow>(
      `UPDATE rental_applications SET ${fields.join(', ')} WHERE id = $${i}
       RETURNING ${'id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"'}`,
      values,
    );

    const updatedApp = updated.rows[0]!;

    // Applicant-visible record of an information request (not an internal note).
    if (action === 'request_information' && input.reason) {
      await addApplicationNote(client, applicationId, actorId, input.reason, false);
    }

    // Critical lifecycle events are persisted in the SAME transaction as the
    // state change. If the outbox insert fails, the whole transaction rolls
    // back so the state change never persists without its notification.
    if (eventType && isCritical) {
      await notifyStakeholdersTransactional(
        client,
        updatedApp,
        eventType,
        { applicationId: updatedApp.id, status: updatedApp.status, reason: input.reason ?? null },
        { excludeUserId: actorId },
      );
    }

    return updatedApp;
  });

  // Post-commit: best-effort notifications + onboarding handoff.
  if (eventType && !isCritical) {
    await notifyStakeholders(
      application,
      eventType,
      { applicationId: application.id, status: application.status, reason: input.reason ?? null },
      { excludeUserId: actorId },
    );
  }

  const result: TransitionResult = { application };

  if (action === 'approve') {
    const onboarding = await initiateOnboarding(applicationId, actorId);
    result.onboarding = onboarding;
    await notifyStakeholders(
      application,
      'onboarding.initiated',
      { applicationId: application.id, tenancyId: onboarding.tenancyId },
      { excludeUserId: actorId },
    );
  }

  return result;
}

// ---------------------------------------------------------------------------
// Applicant self-service
// ---------------------------------------------------------------------------

export async function saveDraft(
  userId: string,
  input: CreateApplicationInput,
  applicationId?: string,
): Promise<ApplicationRow> {
  if (applicationId) {
    const existing = await pool.query<ApplicationRow>(
      `SELECT id, status FROM rental_applications WHERE id = $1 AND user_id = $2`,
      [applicationId, userId],
    );
    if (!existing.rows[0]) throw new NotFoundError('Draft not found');
    if (existing.rows[0]!.status !== 'draft') {
      throw new ConflictError('Only draft applications can be edited');
    }
    // Update editable fields on the draft.
    const updated = await pool.query<ApplicationRow>(
      `UPDATE rental_applications SET
         unit_id = COALESCE($2, unit_id),
         preferred_start_date = $3, preferred_end_date = $4, proposed_rent_amount = $5,
         employer_name = $6, employer_contact = $7, monthly_income = $8,
         previous_landlord_name = $9, previous_landlord_contact = $10,
         guarantor_name = $11, guarantor_email = $12, guarantor_phone = $13, guarantor_relationship = $14,
         updated_by = $15, updated_at = NOW()
       WHERE id = $1
       RETURNING id, property_id as "propertyId", unit_id as "unitId", user_id as "userId", applicant_name as "applicantName", applicant_email as "applicantEmail", applicant_phone as "applicantPhone", applicant_id_number as "applicantIdNumber", applicant_id_type as "applicantIdType", status, preferred_start_date as "preferredStartDate", preferred_end_date as "preferredEndDate", proposed_rent_amount as "proposedRentAmount", documents, employer_name as "employerName", employer_contact as "employerContact", monthly_income as "monthlyIncome", previous_landlord_name as "previousLandlordName", previous_landlord_contact as "previousLandlordContact", guarantor_name as "guarantorName", guarantor_email as "guarantorEmail", guarantor_phone as "guarantorPhone", guarantor_id_number as "guarantorIdNumber", guarantor_relationship as "guarantorRelationship", reviewed_by as "reviewedBy", reviewed_at as "reviewedAt", review_notes as "reviewNotes", rejection_reason as "rejectionReason", approved_by as "approvedBy", approved_at as "approvedAt", approved_rent_amount as "approvedRentAmount", approved_deposit_amount as "approvedDepositAmount", approved_start_date as "approvedStartDate", approved_end_date as "approvedEndDate", tenancy_id as "tenancyId", created_at as "createdAt", updated_at as "updatedAt"`,
      [
        applicationId,
        input.unitId ?? null,
        input.preferredStartDate ? new Date(input.preferredStartDate) : null,
        input.preferredEndDate ? new Date(input.preferredEndDate) : null,
        input.proposedRentAmount ?? null,
        input.employerName ?? null,
        input.employerContact ?? null,
        input.monthlyIncome ?? null,
        input.previousLandlordName ?? null,
        input.previousLandlordContact ?? null,
        input.guarantorName ?? null,
        input.guarantorEmail ?? null,
        input.guarantorPhone ?? null,
        input.guarantorRelationship ?? null,
        userId,
      ],
    );
    return updated.rows[0]!;
  }
  return createApplication(userId, input, true);
}

export async function submitDraft(userId: string, applicationId: string): Promise<ApplicationRow> {
  const result = await transitionApplication({
    applicationId,
    actorId: userId,
    actorKind: 'applicant',
    action: 'submit',
  });
  return result.application;
}

export interface ResubmitInput {
  preferredStartDate?: string | null;
  preferredEndDate?: string | null;
  proposedRentAmount?: number | null;
  employerName?: string | null;
  employerContact?: string | null;
  monthlyIncome?: number | null;
  guarantorName?: string | null;
  guarantorPhone?: string | null;
  responseNote?: string | null;
}

export async function resubmitApplication(
  userId: string,
  applicationId: string,
  input: ResubmitInput,
): Promise<ApplicationRow> {
  // Apply the applicant's updated answers first (only meaningful fields), then
  // perform the information_requested|pending_documents -> resubmitted transition.
  await transaction(async (client) => {
    const app = await findApplication(client, applicationId, true);
    if (!app) throw new NotFoundError('Application not found');
    if (app.userId !== userId) throw new ForbiddenError('You can only resubmit your own application');
    const fields: string[] = [];
    const values: unknown[] = [];
    let i = 1;
    const map: Record<string, string> = {
      preferredStartDate: 'preferred_start_date',
      preferredEndDate: 'preferred_end_date',
      proposedRentAmount: 'proposed_rent_amount',
      employerName: 'employer_name',
      employerContact: 'employer_contact',
      monthlyIncome: 'monthly_income',
      guarantorName: 'guarantor_name',
      guarantorPhone: 'guarantor_phone',
    };
    for (const [key, col] of Object.entries(map)) {
      const v = (input as Record<string, unknown>)[key];
      if (v !== undefined) {
        const value = (key === 'preferredStartDate' || key === 'preferredEndDate')
          ? (v ? new Date(v as string) : null)
          : v;
        fields.push(`${col} = $${i++}`);
        values.push(value);
      }
    }
    if (fields.length > 0) {
      fields.push(`updated_by = $${i++}`);
      values.push(userId);
      values.push(applicationId);
      await client.query(
        `UPDATE rental_applications SET ${fields.join(', ')} WHERE id = $${i}`,
        values,
      );
    }
  });

  const result = await transitionApplication({
    applicationId,
    actorId: userId,
    actorKind: 'applicant',
    action: 'resubmit',
    reason: input.responseNote ?? null,
  });
  if (input.responseNote) {
    await addApplicationNote(pool, applicationId, userId, input.responseNote, false);
  }
  return result.application;
}

export async function withdrawApplication(userId: string, applicationId: string): Promise<ApplicationRow> {
  const result = await transitionApplication({
    applicationId,
    actorId: userId,
    actorKind: 'applicant',
    action: 'withdraw',
  });
  return result.application;
}

// ---------------------------------------------------------------------------
// Manager read + notes
// ---------------------------------------------------------------------------

export async function listInbox(
  managerUserId: string,
  filters: InboxFilters,
): Promise<{ items: unknown[]; total: number; limit: number; offset: number }> {
  const { items, total } = await listManagedApplications(managerUserId, filters);
  return { items, total, limit: filters.limit, offset: filters.offset };
}

export interface ApplicationDetail {
  application: ApplicationRow & { propertyTitle?: string; city?: string | null; county?: string | null };
  history: unknown[];
  notes: unknown[];
  documents: unknown[];
}

export async function getApplicationDetail(
  actorId: string,
  applicationId: string,
): Promise<ApplicationDetail> {
  const app = await findApplication(pool, applicationId);
  if (!app) throw new NotFoundError('Application not found');

  const scope = await getManagerScope(pool, actorId, app);
  if (!scope.isApplicant && !scope.isManager) {
    throw new ForbiddenError('You are not authorized to view this application');
  }

  const prop = await pool.query<{ title: string; city: string | null; county: string | null }>(
    `SELECT title, city, county FROM properties WHERE id = $1`,
    [app.propertyId],
  );

  const [history, notes, documents] = await Promise.all([
    listApplicationHistory(applicationId),
    // Applicants never see internal notes.
    listApplicationNotes(applicationId, { applicantView: !scope.isManager || scope.isApplicant }),
    listApplicationDocuments(applicationId),
  ]);

  return {
    application: { ...app, ...(prop.rows[0] ?? {}) },
    history,
    notes,
    documents,
  };
}

/**
 * Retry the idempotent tenant-onboarding handoff for an already-approved
 * application. Manager-only; safe to call repeatedly.
 */
export async function retryOnboarding(managerUserId: string, applicationId: string) {
  const app = await findApplication(pool, applicationId);
  if (!app) throw new NotFoundError('Application not found');
  const scope = await getManagerScope(pool, managerUserId, app);
  if (!scope.isManager) throw new ForbiddenError('Only managers can initiate onboarding');
  return initiateOnboarding(applicationId, managerUserId);
}

export async function addInternalNote(
  managerUserId: string,
  applicationId: string,
  note: string,
): Promise<unknown> {
  const app = await findApplication(pool, applicationId);
  if (!app) throw new NotFoundError('Application not found');
  const scope = await getManagerScope(pool, managerUserId, app);
  if (!scope.isManager) throw new ForbiddenError('Only managers can add internal notes');
  if (!note || !note.trim()) throw new ValidationError('Note cannot be empty');
  return transaction((client) => addApplicationNote(client, applicationId, managerUserId, note.trim(), true));
}

// ---------------------------------------------------------------------------
// Secure documents
// ---------------------------------------------------------------------------

export interface UploadDocumentInput {
  storageKey: string;
  fileName: string;
  mimeType: string | null;
  fileSizeBytes: number | null;
  category?: string;
}

export async function attachDocument(
  actorId: string,
  applicationId: string,
  input: UploadDocumentInput,
): Promise<unknown> {
  const app = await findApplication(pool, applicationId);
  if (!app) throw new NotFoundError('Application not found');
  // Only the applicant (owner) may attach documents to their application.
  if (app.userId !== actorId) throw new ForbiddenError('You can only add documents to your own application');
  return transaction((client) =>
    insertApplicationDocument(client, {
      applicationId,
      uploadedBy: actorId,
      storageKey: input.storageKey,
      fileName: input.fileName,
      mimeType: input.mimeType,
      fileSizeBytes: input.fileSizeBytes,
      category: input.category ?? 'supporting',
    }),
  );
}

export async function getDocumentForDownload(
  actorId: string,
  documentId: string,
): Promise<{ storageKey: string; fileName: string; mimeType: string | null }> {
  const doc = await findApplicationDocument(documentId);
  if (!doc) throw new NotFoundError('Document not found');
  const app = await findApplication(pool, doc.applicationId);
  if (!app) throw new NotFoundError('Application not found');
  const scope = await getManagerScope(pool, actorId, app);
  if (!scope.isApplicant && !scope.isManager) {
    throw new ForbiddenError('You are not authorized to download this document');
  }
  return { storageKey: doc.storageKey, fileName: doc.fileName, mimeType: doc.mimeType };
}

// Re-exported so controllers can validate statuses without importing the
// lifecycle module directly.
export { isApplicationStatus };
export { assertEligibleProperty, assertUnitAvailable };