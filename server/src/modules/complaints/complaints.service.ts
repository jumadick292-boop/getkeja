// Provider complaints service (Task 13.16). Enforces resource-scoped access,
// a documented lifecycle, customer/provider/admin messages, provider corrective
// actions, private admin notes, assignment, escalation and resolution. Internal
// notes are never exposed to customers/providers. A complaint never mutates the
// underlying job and never triggers financial flows.
import { transaction } from '../../db/tx.js';
import { ConflictError, ForbiddenError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { resolveProviderContext } from '../provider/provider.authorization.js';
import * as authz from '../auth/authorization.service.js';
import { enqueueOutboxEventTransactional } from '../auth/transactional-outbox.service.js';
import { isOperationalDomain, loadOperationalResource } from '../../shared/operationalResources.js';
import type { ComplaintActor, ComplaintStatus } from './complaints.types.js';
import type { CreateComplaintInput } from './complaints.schemas.js';
import { assertComplaintTransition } from './complaints.lifecycle.js';
import * as repo from './complaints.repository.js';

async function emit(client: Parameters<Parameters<typeof transaction>[0]>[0], eventType: string, complaintId: string, recipientUserIds: string[], organisationId: string | null, payload: Record<string, unknown>) {
  await enqueueOutboxEventTransactional(client, {
    idempotencyKey: `${eventType}:${complaintId}`,
    eventType,
    category: 'support',
    priority: 'high',
    recipientUserIds,
    organisationId,
    resourceType: 'complaint',
    resourceId: complaintId,
    payload,
    channels: ['in_app'],
    classification: 'critical',
  });
}

async function isPlatformAdmin(userId: string): Promise<boolean> {
  return (await authz.hasPermission(userId, 'complaint.manage')) || (await authz.hasSystemRole(userId));
}

// Resolve the actor relationship for a complaint, or throw.
async function resolveActor(userId: string, complaint: { customerUserId: string; providerProfileId: string; providerOrganisationId: string | null }, organizationId?: string | null): Promise<ComplaintActor> {
  if (complaint.customerUserId === userId) return 'customer';
  if (await isPlatformAdmin(userId)) return 'admin';
  const context = await resolveProviderContext(userId, organizationId);
  if (context.isProvider && context.effectiveProfileIds.includes(complaint.providerProfileId)) return 'provider';
  throw new ForbiddenError('You are not authorized for this complaint');
}

export async function listReasons() {
  return repo.listReasons();
}

export async function submitComplaint(userId: string, domain: string, resourceId: string, input: CreateComplaintInput) {
  if (!isOperationalDomain(domain)) throw new ValidationError('Unsupported operational domain');
  const ref = await loadOperationalResource(domain, resourceId);
  if (!ref) throw new NotFoundError('Operational job not found');
  if (ref.customerUserId !== userId) throw new ForbiddenError('You may only complain about your own jobs');
  const reasons = await repo.listReasons();
  if (!reasons.some((r) => r.id === input.reasonId)) throw new ValidationError('Unknown complaint reason');

  const created = await transaction(async (client) => {
    const row = await repo.insertComplaint(client, {
      domain, resourceId, customerUserId: userId, providerProfileId: ref.providerProfileId,
      providerOrganisationId: ref.providerOrganisationId, reasonId: input.reasonId,
      description: input.description, documentIds: input.documentIds ?? [],
    });
    await repo.insertHistory(client, { complaintId: row.id, previous: null, next: 'submitted', changedBy: userId, reason: null });
    // Notify the provider profile owner(s) is resolved by the worker via resource.
    await emit(client, 'complaint.submitted', row.id, [userId], ref.providerOrganisationId, { complaintId: row.id });
    return row;
  });
  return repo.getDetail({ ...(await repo.findById(created.id))! }, false);
}

export async function listCustomerComplaints(userId: string, status?: string, limit = 20, offset = 0) {
  return repo.listCustomerComplaints(userId, status, limit, offset);
}

export async function listProviderComplaints(userId: string, organizationId: string | null | undefined, status?: string, limit = 20, offset = 0) {
  const context = await resolveProviderContext(userId, organizationId);
  if (!context.isProvider) throw new ForbiddenError('No provider context');
  return repo.listProviderComplaints(context.effectiveProfileIds, status, limit, offset);
}

export async function listAdminQueue(userId: string, status?: string, limit = 20, offset = 0) {
  if (!(await isPlatformAdmin(userId))) throw new ForbiddenError('Missing permission: complaint.manage');
  return repo.listAdminQueue(status, limit, offset);
}

export async function getComplaint(userId: string, organizationId: string | null | undefined, complaintId: string) {
  const complaint = await repo.findById(complaintId);
  if (!complaint) throw new NotFoundError('Complaint not found');
  const actor = await resolveActor(userId, complaint, organizationId);
  return repo.getDetail(complaint, actor === 'admin');
}

async function transition(userId: string, organizationId: string | null | undefined, complaintId: string, to: ComplaintStatus, reason?: string | null, resolutionSummary?: string | null) {
  const complaint = await repo.findById(complaintId);
  if (!complaint) throw new NotFoundError('Complaint not found');
  const actor = await resolveActor(userId, complaint, organizationId);
  assertComplaintTransition(complaint.status, to, actor);
  const extra: Record<string, unknown> = {};
  if (to === 'resolved') { extra.resolved_at = new Date().toISOString(); if (resolutionSummary) extra.resolution_summary = resolutionSummary; }
  if (to === 'closed') extra.closed_at = new Date().toISOString();
  const recipients = [complaint.customerUserId];
  await transaction(async (client) => {
    await repo.updateStatus(complaint.id, to, extra);
    await repo.insertHistory(client, { complaintId: complaint.id, previous: complaint.status, next: to, changedBy: userId, reason: reason ?? null });
    await emit(client, `complaint.${to}`, complaint.id, recipients, complaint.providerOrganisationId, { from: complaint.status, reason: reason ?? null });
  });
  return repo.getDetail({ ...(await repo.findById(complaintId))! }, actor === 'admin');
}

export async function postMessage(userId: string, organizationId: string | null | undefined, complaintId: string, body: string, documentIds: string[] = []) {
  const complaint = await repo.findById(complaintId);
  if (!complaint) throw new NotFoundError('Complaint not found');
  const actor = await resolveActor(userId, complaint, organizationId);
  await transaction(async (client) => {
    await repo.insertMessage(client, { complaintId, authorUserId: userId, authorRole: actor, body, documentIds });
  });
  return repo.getDetail(complaint, actor === 'admin');
}

export async function recordCorrectiveAction(userId: string, organizationId: string | null | undefined, complaintId: string, action: string) {
  const complaint = await repo.findById(complaintId);
  if (!complaint) throw new NotFoundError('Complaint not found');
  const actor = await resolveActor(userId, complaint, organizationId);
  if (actor === 'customer') throw new ForbiddenError('Only providers or admins may record corrective actions');
  if (actor === 'provider' && !(await authz.hasPermission(userId, 'provider.complaints.respond'))) {
    throw new ForbiddenError('Missing permission: provider.complaints.respond');
  }
  await transaction(async (client) => {
    await repo.insertCorrectiveAction(client, complaintId, userId, action);
  });
  return repo.getDetail(complaint, actor === 'admin');
}

export async function addInternalNote(userId: string, complaintId: string, body: string) {
  if (!(await isPlatformAdmin(userId))) throw new ForbiddenError('Missing permission: complaint.manage');
  const complaint = await repo.findById(complaintId);
  if (!complaint) throw new NotFoundError('Complaint not found');
  await transaction(async (client) => {
    await repo.insertInternalNote(client, complaintId, userId, body);
  });
  return repo.getDetail(complaint, true);
}

export async function assignComplaint(userId: string, complaintId: string, adminUserId: string) {
  if (!(await isPlatformAdmin(userId))) throw new ForbiddenError('Missing permission: complaint.manage');
  const complaint = await repo.findById(complaintId);
  if (!complaint) throw new NotFoundError('Complaint not found');
  await repo.setAssignee(complaintId, adminUserId);
  return repo.getDetail({ ...(await repo.findById(complaintId))! }, true);
}

export async function changeStatus(userId: string, organizationId: string | null | undefined, complaintId: string, to: ComplaintStatus, reason?: string | null, resolutionSummary?: string | null) {
  return transition(userId, organizationId, complaintId, to, reason, resolutionSummary);
}