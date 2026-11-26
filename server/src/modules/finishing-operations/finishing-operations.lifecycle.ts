// Finishing & Building Services lifecycle (Task 13.15) — validated transition
// matrix with stage skipping. A shared finishing engine accommodates roofing,
// flooring, tiling and painting differences (site inspection/measurement, work
// plan, materials/finish hold, quality inspection, handover) without separate
// lifecycle engines. Weather/site interruptions are modelled via the exception
// status + rescheduling, not a dedicated stage.
import { ConflictError } from '../../shared/errors.js';
import type { FinishingActor, FinishingOperationStatus } from './finishing-operations.types.js';

export const FINISHING_STATUSES: FinishingOperationStatus[] = [
  'confirmed', 'assessment_scheduled', 'awaiting_assessment',
  'assessment_in_progress', 'plan_prepared', 'awaiting_customer_approval',
  'scheduled', 'assigned', 'materials_prepared', 'in_progress',
  'awaiting_materials', 'quality_inspection', 'awaiting_handover',
  'completed_pending_confirmation', 'completed', 'cancelled', 'failed',
  'exception',
];

export interface FinishingTransition {
  from: FinishingOperationStatus;
  to: FinishingOperationStatus;
  actor: FinishingActor;
}

const TERMINAL: FinishingOperationStatus[] = ['completed', 'cancelled', 'failed'];

function buildTransitions(): FinishingTransition[] {
  const list: FinishingTransition[] = [];
  const add = (from: FinishingOperationStatus, to: FinishingOperationStatus, actor: FinishingActor) =>
    list.push({ from, to, actor });

  // Confirmed → optional inspection path, or straight to scheduling/assignment.
  add('confirmed', 'assessment_scheduled', 'provider');
  add('confirmed', 'scheduled', 'provider');
  add('confirmed', 'assigned', 'provider');
  add('confirmed', 'in_progress', 'provider');
  add('assessment_scheduled', 'awaiting_assessment', 'provider');
  add('assessment_scheduled', 'assessment_in_progress', 'provider');
  add('awaiting_assessment', 'assessment_in_progress', 'provider');
  add('assessment_in_progress', 'plan_prepared', 'provider');
  add('assessment_in_progress', 'awaiting_customer_approval', 'provider');
  add('assessment_in_progress', 'scheduled', 'provider');
  add('assessment_in_progress', 'assigned', 'provider');
  add('plan_prepared', 'awaiting_customer_approval', 'provider');
  add('plan_prepared', 'scheduled', 'provider');
  add('plan_prepared', 'assigned', 'provider');
  add('awaiting_customer_approval', 'scheduled', 'provider');
  add('awaiting_customer_approval', 'assigned', 'provider');
  add('awaiting_customer_approval', 'in_progress', 'provider');

  // Work execution with forward skipping + materials hold.
  add('scheduled', 'assigned', 'provider');
  add('scheduled', 'in_progress', 'provider');
  add('assigned', 'materials_prepared', 'provider');
  add('assigned', 'in_progress', 'provider');
  add('materials_prepared', 'in_progress', 'provider');
  add('in_progress', 'awaiting_materials', 'provider');
  add('awaiting_materials', 'in_progress', 'provider');
  add('awaiting_materials', 'materials_prepared', 'provider');
  add('in_progress', 'awaiting_customer_approval', 'provider');
  add('awaiting_materials', 'awaiting_customer_approval', 'provider');
  add('in_progress', 'quality_inspection', 'provider');
  add('awaiting_materials', 'quality_inspection', 'provider');
  add('quality_inspection', 'awaiting_handover', 'provider');
  add('quality_inspection', 'in_progress', 'provider');
  add('awaiting_handover', 'completed_pending_confirmation', 'provider');
  add('awaiting_handover', 'in_progress', 'provider');

  // Completion requires customer confirmation.
  add('completed_pending_confirmation', 'completed', 'customer');
  add('completed_pending_confirmation', 'exception', 'customer');
  add('completed_pending_confirmation', 'in_progress', 'customer');

  // Cancellation / failure / exception from any non-terminal state.
  for (const status of FINISHING_STATUSES) {
    if (TERMINAL.includes(status)) continue;
    add(status, 'cancelled', 'customer');
    add(status, 'cancelled', 'provider');
    add(status, 'failed', 'provider');
    if (status !== 'exception') add(status, 'exception', 'provider');
  }
  return list;
}

export const FINISHING_TRANSITIONS: FinishingTransition[] = buildTransitions();

export function isFinishingTerminal(status: FinishingOperationStatus): boolean {
  return TERMINAL.includes(status);
}

export function isFinishingTransitionAllowed(
  from: FinishingOperationStatus,
  to: FinishingOperationStatus,
  actor: FinishingActor,
): boolean {
  return FINISHING_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertFinishingTransition(
  from: FinishingOperationStatus,
  to: FinishingOperationStatus,
  actor: FinishingActor,
): void {
  if (isFinishingTerminal(from) && from !== to) {
    throw new ConflictError(`Finishing job is ${from} and cannot be transitioned`);
  }
  if (!isFinishingTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}