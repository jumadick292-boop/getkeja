// Garbage collection lifecycle (Task 13.7) — validated transition matrix.
import { ConflictError } from '../../shared/errors.js';
import type { GarbageActor, GarbageCollectionStatus } from './garbage.types.js';

export const GARBAGE_JOB_STATUSES: GarbageCollectionStatus[] = [
  'confirmed', 'scheduled', 'provider_assigned', 'en_route', 'arrived',
  'collecting', 'completed', 'awaiting_customer_confirmation',
  'cancelled', 'missed', 'failed', 'rescheduled',
];

export interface GarbageTransition {
  from: GarbageCollectionStatus;
  to: GarbageCollectionStatus;
  actor: GarbageActor;
}

const ACTIVE: GarbageCollectionStatus[] = [
  'confirmed', 'scheduled', 'provider_assigned', 'en_route', 'arrived', 'collecting',
];

export const GARBAGE_TRANSITIONS: GarbageTransition[] = [
  { from: 'confirmed', to: 'scheduled', actor: 'provider' },
  { from: 'confirmed', to: 'provider_assigned', actor: 'provider' },
  { from: 'scheduled', to: 'provider_assigned', actor: 'provider' },
  { from: 'provider_assigned', to: 'en_route', actor: 'provider' },
  { from: 'en_route', to: 'arrived', actor: 'provider' },
  { from: 'arrived', to: 'collecting', actor: 'provider' },
  { from: 'collecting', to: 'awaiting_customer_confirmation', actor: 'provider' },
  { from: 'awaiting_customer_confirmation', to: 'completed', actor: 'customer' },
  // Reschedule from active states.
  ...ACTIVE.map((s) => ({ from: s, to: 'rescheduled' as GarbageCollectionStatus, actor: 'provider' as GarbageActor })),
  { from: 'rescheduled', to: 'scheduled', actor: 'provider' },
  // Missed / failed (provider).
  ...ACTIVE.map((s) => ({ from: s, to: 'missed' as GarbageCollectionStatus, actor: 'provider' as GarbageActor })),
  ...ACTIVE.map((s) => ({ from: s, to: 'failed' as GarbageCollectionStatus, actor: 'provider' as GarbageActor })),
  // Cancellation (customer or provider) from any non-terminal state.
  ...GARBAGE_JOB_STATUSES.filter(
    (s) => !['completed', 'cancelled', 'missed', 'failed'].includes(s),
  ).flatMap((s) => [
    { from: s, to: 'cancelled' as GarbageCollectionStatus, actor: 'customer' as GarbageActor },
    { from: s, to: 'cancelled' as GarbageCollectionStatus, actor: 'provider' as GarbageActor },
  ]),
];

export function isGarbageTerminal(status: GarbageCollectionStatus): boolean {
  return ['completed', 'cancelled', 'missed', 'failed'].includes(status);
}

export function isGarbageTransitionAllowed(
  from: GarbageCollectionStatus,
  to: GarbageCollectionStatus,
  actor: GarbageActor,
): boolean {
  return GARBAGE_TRANSITIONS.some((t) => t.from === from && t.to === to && t.actor === actor);
}

export function assertGarbageTransition(
  from: GarbageCollectionStatus,
  to: GarbageCollectionStatus,
  actor: GarbageActor,
): void {
  if (isGarbageTerminal(from) && from !== to) {
    throw new ConflictError(`Collection is ${from} and cannot be transitioned`);
  }
  if (!isGarbageTransitionAllowed(from, to, actor)) {
    throw new ConflictError(`Transition ${from} -> ${to} is not permitted for ${actor}`);
  }
}

// Default operational checklist for a garbage collection.
export const GARBAGE_CHECKLIST_TEMPLATE = [
  { id: 'bins_present', label: 'Bins present and accessible' },
  { id: 'access_clear', label: 'Collection access clear' },
  { id: 'waste_sorted', label: 'Waste sorted by category' },
  { id: 'area_clean', label: 'Area left clean' },
];