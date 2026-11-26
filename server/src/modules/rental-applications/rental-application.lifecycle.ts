// Rental application lifecycle state machine.
//
// This module is the single authority for which status transitions are legal
// and who may perform them. Services call `resolveTransition` before mutating
// a row; the database trigger (migration 093) records the resulting history.
//
// Statuses mirror the `application_status` enum (migrations 048 + 093). Legacy
// values (pending_documents, pending_payment) are retained for historical rows
// and remain transition-capable.

export type ApplicationStatus =
  | 'draft'
  | 'submitted'
  | 'under_review'
  | 'information_requested'
  | 'resubmitted'
  | 'shortlisted'
  | 'proposal_sent'
  | 'negotiation'
  | 'approved'
  | 'rejected'
  | 'withdrawn'
  | 'expired'
  | 'cancelled'
  | 'pending_documents'
  | 'pending_payment';

export type ActorKind = 'applicant' | 'manager' | 'system';

export type LifecycleAction =
  | 'submit'
  | 'start_review'
  | 'request_information'
  | 'resubmit'
  | 'shortlist'
  | 'send_proposal'
  | 'start_negotiation'
  | 'approve'
  | 'reject'
  | 'withdraw'
  | 'cancel'
  | 'expire';

interface TransitionRule {
  to: ApplicationStatus;
  actors: ActorKind[];
}

// Terminal states cannot transition further (except system expiry, which never
// applies to them anyway).
export const TERMINAL_STATUSES: ReadonlySet<ApplicationStatus> = new Set([
  'approved',
  'rejected',
  'withdrawn',
  'expired',
  'cancelled',
]);

// Statuses that represent an open, actionable application (used for duplicate
// detection and "active" filtering). Terminal + draft are excluded.
export const ACTIVE_STATUSES: ReadonlySet<ApplicationStatus> = new Set([
  'submitted',
  'under_review',
  'information_requested',
  'resubmitted',
  'shortlisted',
  'proposal_sent',
  'negotiation',
  'pending_documents',
  'pending_payment',
]);

// The transition table. Keyed by the action; each action lists the statuses it
// may be invoked from and the actor kinds allowed.
const TRANSITIONS: Record<LifecycleAction, { from: ApplicationStatus[]; rule: TransitionRule }> = {
  submit: {
    from: ['draft'],
    rule: { to: 'submitted', actors: ['applicant'] },
  },
  start_review: {
    from: ['submitted', 'resubmitted', 'pending_documents'],
    rule: { to: 'under_review', actors: ['manager'] },
  },
  request_information: {
    from: ['submitted', 'under_review', 'resubmitted'],
    rule: { to: 'information_requested', actors: ['manager'] },
  },
  resubmit: {
    from: ['information_requested', 'pending_documents'],
    rule: { to: 'resubmitted', actors: ['applicant'] },
  },
  shortlist: {
    from: ['submitted', 'under_review', 'resubmitted'],
    rule: { to: 'shortlisted', actors: ['manager'] },
  },
  send_proposal: {
    from: ['shortlisted', 'under_review', 'proposal_sent', 'negotiation'],
    rule: { to: 'proposal_sent', actors: ['manager'] },
  },
  start_negotiation: {
    from: ['proposal_sent', 'shortlisted'],
    rule: { to: 'negotiation', actors: ['applicant', 'manager'] },
  },
  approve: {
    from: ['under_review', 'shortlisted', 'negotiation', 'proposal_sent', 'pending_payment'],
    rule: { to: 'approved', actors: ['manager'] },
  },
  reject: {
    from: [
      'submitted',
      'under_review',
      'information_requested',
      'resubmitted',
      'shortlisted',
      'proposal_sent',
      'negotiation',
      'pending_documents',
      'pending_payment',
    ],
    rule: { to: 'rejected', actors: ['manager'] },
  },
  withdraw: {
    from: [
      'draft',
      'submitted',
      'under_review',
      'information_requested',
      'resubmitted',
      'shortlisted',
      'proposal_sent',
      'negotiation',
      'pending_documents',
      'pending_payment',
    ],
    rule: { to: 'withdrawn', actors: ['applicant'] },
  },
  cancel: {
    from: ['draft', 'submitted', 'under_review'],
    rule: { to: 'cancelled', actors: ['applicant', 'manager'] },
  },
  expire: {
    from: [
      'draft',
      'submitted',
      'under_review',
      'information_requested',
      'resubmitted',
      'shortlisted',
      'proposal_sent',
      'negotiation',
      'pending_documents',
      'pending_payment',
    ],
    rule: { to: 'expired', actors: ['system'] },
  },
};

export interface TransitionResolution {
  ok: boolean;
  to?: ApplicationStatus;
  reason?: string;
}

/**
 * Resolve whether `action` may move an application from `from` to a new status
 * under `actor`. Returns the target status on success, or a human-readable
 * reason on failure. Pure — no I/O.
 */
export function resolveTransition(
  from: ApplicationStatus,
  action: LifecycleAction,
  actor: ActorKind,
): TransitionResolution {
  const def = TRANSITIONS[action];
  if (!def) return { ok: false, reason: `Unknown action: ${action}` };
  if (!def.rule.actors.includes(actor)) {
    return { ok: false, reason: `Action '${action}' is not permitted for ${actor}s` };
  }
  if (!def.from.includes(from)) {
    return { ok: false, reason: `Cannot '${action}' an application in status '${from}'` };
  }
  return { ok: true, to: def.rule.to };
}

/** All statuses an actor may move a given status to via any single action. */
export function allowedTargets(from: ApplicationStatus, actor: ActorKind): ApplicationStatus[] {
  const out: ApplicationStatus[] = [];
  for (const action of Object.keys(TRANSITIONS) as LifecycleAction[]) {
    const res = resolveTransition(from, action, actor);
    if (res.ok && res.to) out.push(res.to);
  }
  return out;
}

export function isTerminal(status: ApplicationStatus): boolean {
  return TERMINAL_STATUSES.has(status);
}

export function isActive(status: ApplicationStatus): boolean {
  return ACTIVE_STATUSES.has(status);
}

export function isApplicationStatus(value: string): value is ApplicationStatus {
  return (
    value in
    {
      draft: 1,
      submitted: 1,
      under_review: 1,
      information_requested: 1,
      resubmitted: 1,
      shortlisted: 1,
      proposal_sent: 1,
      negotiation: 1,
      approved: 1,
      rejected: 1,
      withdrawn: 1,
      expired: 1,
      cancelled: 1,
      pending_documents: 1,
      pending_payment: 1,
    }
  );
}