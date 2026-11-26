// Complaint lifecycle (Task 13.16) — documented transition matrix with actor
// scoping. A complaint never changes a job's completion status and never
// triggers financial flows.
import { ConflictError } from '../../shared/errors.js';
import type { ComplaintActor, ComplaintStatus } from './complaints.types.js';

export const COMPLAINT_STATUSES: ComplaintStatus[] = [
  'submitted', 'acknowledged', 'under_review', 'awaiting_customer_information',
  'awaiting_provider_response', 'resolution_proposed', 'resolved', 'escalated', 'closed',
];

export interface ComplaintTransition {
  from: ComplaintStatus;
  to: ComplaintStatus;
  actor: ComplaintActor;
}

// Only 'closed' is truly terminal; 'resolved' may still be closed or reopened.
const TERMINAL: ComplaintStatus[] = ['closed'];

function build(): ComplaintTransition[] {
  const list: ComplaintTransition[] = [];
  const add = (from: ComplaintStatus, to: ComplaintStatus, actor: ComplaintActor) => list.push({ from, to, actor });

  add('submitted', 'acknowledged', 'provider');
  add('submitted', 'acknowledged', 'admin');
  add('submitted', 'under_review', 'admin');
  add('acknowledged', 'under_review', 'provider');
  add('acknowledged', 'under_review', 'admin');
  add('under_review', 'awaiting_customer_information', 'provider');
  add('under_review', 'awaiting_customer_information', 'admin');
  add('under_review', 'awaiting_provider_response', 'admin');
  add('under_review', 'resolution_proposed', 'provider');
  add('under_review', 'resolution_proposed', 'admin');
  add('awaiting_customer_information', 'under_review', 'provider');
  add('awaiting_customer_information', 'under_review', 'admin');
  add('awaiting_provider_response', 'under_review', 'provider');
  add('awaiting_provider_response', 'under_review', 'admin');
  add('awaiting_provider_response', 'resolution_proposed', 'provider');
  add('resolution_proposed', 'resolved', 'admin');
  add('resolution_proposed', 'resolved', 'customer');
  add('resolution_proposed', 'under_review', 'admin');
  add('resolved', 'closed', 'admin');
  add('resolved', 'under_review', 'admin');
  add('resolved', 'under_review', 'customer');

  // Escalation from any non-terminal, non-escalated state (admin only).
  for (const status of COMPLAINT_STATUSES) {
    if (TERMINAL.includes(status) || status === 'escalated') continue;
    add(status, 'escalated', 'admin');
  }
  add('escalated', 'under_review', 'admin');
  add('escalated', 'closed', 'admin');
  return list;
}

export const COMPLAINT_TRANSITIONS: ComplaintTransition[] = build();

export function isComplaintTerminal(status: ComplaintStatus): boolean {
  return TERMINAL.includes(status);
}

export function isComplaintTransitionAllowed(from: ComplaintStatus, to: ComplaintStatus, actor: ComplaintActor): boolean {
  return COMPLAINT_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertComplaintTransition(from: ComplaintStatus, to: ComplaintStatus, actor: ComplaintActor): void {
  if (isComplaintTerminal(from) && from !== to) {
    throw new ConflictError(`Complaint is ${from} and cannot be transitioned to ${to}`);
  }
  if (!isComplaintTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}