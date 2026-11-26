import type { PoolClient } from 'pg';
import { pool } from '../../db/pool.js';
import { ForbiddenError, HttpError, NotFoundError, ValidationError } from '../../shared/errors.js';
import { NotificationService } from '../auth/notification.service.js';
import * as repo from './messaging.repository.js';
import type {
  AttachmentRow,
  ConversationContextType,
  ConversationListItem,
  ConversationRow,
  MessageListItem,
} from './messaging.repository.js';

const notifications = new NotificationService();

const MAX_MESSAGE_LENGTH = 5000;

// ---------------------------------------------------------------------------
// Authorized participant derivation for a business context.
//
// A conversation is only ever created for a real, authorized context (an
// enquiry, a site visit, a tenancy). The set of users allowed in the resulting
// conversation is derived from the platform's own ownership / assignment data;
// a client can never inject an arbitrary counterpart.
// ---------------------------------------------------------------------------

interface PropertySideResolution {
  propertyId: string | null;
  unitId: string | null;
  /** Owner/manager/agent users who may participate. Excludes caretakers. */
  managers: string[];
}

/**
 * Owner/manager/agent users for a property. This intentionally uses ownership
 * and property_assignments limited to the staff assignment types
 * (property_manager, letting_agent), and NOT unit_access_assignments, so a
 * caretaker (or maintenance/security/other staff) with property or unit access
 * never inherits landlord messaging privileges.
 */
export async function derivePropertyManagers(
  connection: PoolClient | typeof pool,
  propertyId: string,
): Promise<string[]> {
  const result = await connection.query<{ user_id: string }>(
    `SELECT po.user_id AS user_id
       FROM property_ownerships po
      WHERE po.property_id = $1 AND po.status = 'active' AND po.user_id IS NOT NULL
        AND (po.effective_to IS NULL OR po.effective_to > NOW())
      UNION
      SELECT pa.user_id AS user_id
       FROM property_assignments pa
      WHERE pa.property_id = $1 AND pa.status = 'active' AND pa.user_id IS NOT NULL
        AND pa.assignment_type IN ('property_manager','letting_agent')
        AND (pa.effective_to IS NULL OR pa.effective_to > NOW())`,
    [propertyId],
  );
  return result.rows.map((row) => row.user_id);
}

export interface StartConversationInput {
  type: ConversationContextType;
  subject?: string | null;
  propertyId?: string | null;
  unitId?: string | null;
  enquiryId?: string | null;
  rentalApplicationId?: string | null;
  rentalProposalId?: string | null;
  siteVisitId?: string | null;
  tenancyId?: string | null;
  movingJobId?: string | null;
  marketplaceRequestId?: string | null;
  garbageJobId?: string | null;
  laundryOrderId?: string | null;
  schedulingActivityId?: string | null;
  /** Client-suggested counterpart(s). Validated against the authorized set. */
  participantUserIds?: string[];
  message?: string | null;
}

interface ResolvedContext {
  type: ConversationContextType;
  propertyId: string | null;
  unitId: string | null;
  enquiryId: string | null;
  rentalApplicationId: string | null;
  rentalProposalId: string | null;
  siteVisitId: string | null;
  tenancyId: string | null;
  movingJobId?: string | null;
  marketplaceRequestId?: string | null;
  garbageJobId?: string | null;
  laundryOrderId?: string | null;
  schedulingActivityId?: string | null;
  /** The full authorized participant universe for this context. */
  authorizedUserIds: string[];
  /**
   * For property-only "contact the host" conversations, the initiating user
   * (a prospective renter) is allowed to join even though they are not a
   * property manager. Counterpart ids are still validated against managers.
   */
  allowInitiatorJoin: boolean;
  subject: string | null;
  /** For dedup: the primary context column + id. */
  dedup: {
    column:
      | 'enquiry_id'
      | 'site_visit_id'
      | 'tenancy_id'
      | 'rental_application_id'
      | 'rental_proposal_id'
      | 'moving_job_id'
      | 'marketplace_request_id'
      | 'garbage_job_id'
      | 'laundry_order_id'
      | 'scheduling_activity_id';
    id: string;
  } | null;
}

async function resolveEnquiryContext(
  connection: PoolClient | typeof pool,
  enquiryId: string,
): Promise<ResolvedContext> {
  const enquiry = await connection.query<{
    id: string;
    property_id: string;
    unit_id: string | null;
    prospective_renter_id: string | null;
    prospective_renter_name: string | null;
  }>(
    `SELECT id, property_id, unit_id, prospective_renter_id, prospective_renter_name
       FROM property_enquiries WHERE id = $1`,
    [enquiryId],
  );
  const row = enquiry.rows[0];
  if (!row) throw new NotFoundError('Enquiry');
  const managers = await derivePropertyManagers(connection, row.property_id);
  const authorized = new Set<string>(managers);
  if (row.prospective_renter_id) authorized.add(row.prospective_renter_id);
  return {
    type: 'enquiry',
    propertyId: row.property_id,
    unitId: row.unit_id,
    enquiryId: row.id,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: row.prospective_renter_name
      ? `Enquiry from ${row.prospective_renter_name}`
      : 'Property enquiry',
    dedup: { column: 'enquiry_id', id: row.id },
  };
}

async function resolveSiteVisitContext(
  connection: PoolClient | typeof pool,
  siteVisitId: string,
): Promise<ResolvedContext> {
  const visit = await connection.query<{
    id: string;
    property_id: string;
    unit_id: string | null;
    user_id: string;
    hosted_by_user_id: string | null;
    visitor_name: string;
  }>(
    `SELECT id, property_id, unit_id, user_id, hosted_by_user_id, visitor_name
       FROM site_visits WHERE id = $1`,
    [siteVisitId],
  );
  const row = visit.rows[0];
  if (!row) throw new NotFoundError('Site visit');
  const managers = await derivePropertyManagers(connection, row.property_id);
  const authorized = new Set<string>(managers);
  authorized.add(row.user_id);
  if (row.hosted_by_user_id) authorized.add(row.hosted_by_user_id);
  return {
    type: 'site_visit',
    propertyId: row.property_id,
    unitId: row.unit_id,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: row.id,
    tenancyId: null,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Site visit with ${row.visitor_name}`,
    dedup: { column: 'site_visit_id', id: row.id },
  };
}

async function resolveTenancyContext(
  connection: PoolClient | typeof pool,
  tenancyId: string,
): Promise<ResolvedContext> {
  const tenancy = await connection.query<{ id: string; property_id: string; unit_id: string | null }>(
    `SELECT id, property_id, unit_id FROM tenancies WHERE id = $1`,
    [tenancyId],
  );
  const row = tenancy.rows[0];
  if (!row) throw new NotFoundError('Tenancy');
  const managers = await derivePropertyManagers(connection, row.property_id);
  const authorized = new Set<string>(managers);
  const tenantUsers = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM tenants WHERE tenancy_id = $1 AND user_id IS NOT NULL AND status = 'active'`,
    [tenancyId],
  );
  for (const tenant of tenantUsers.rows) authorized.add(tenant.user_id);
  return {
    type: 'tenancy',
    propertyId: row.property_id,
    unitId: row.unit_id,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: row.id,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: 'Tenancy conversation',
    dedup: { column: 'tenancy_id', id: row.id },
  };
}

async function resolveRentalApplicationContext(
  connection: PoolClient | typeof pool,
  applicationId: string,
): Promise<ResolvedContext> {
  const app = await connection.query<{
    id: string;
    property_id: string;
    unit_id: string | null;
    user_id: string | null;
    applicant_name: string;
  }>(
    `SELECT id, property_id, unit_id, user_id, applicant_name
       FROM rental_applications WHERE id = $1`,
    [applicationId],
  );
  const row = app.rows[0];
  if (!row) throw new NotFoundError('Rental application');
  const managers = await derivePropertyManagers(connection, row.property_id);
  const authorized = new Set<string>(managers);
  if (row.user_id) authorized.add(row.user_id);
  return {
    type: 'rental_application',
    propertyId: row.property_id,
    unitId: row.unit_id,
    enquiryId: null,
    rentalApplicationId: row.id,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Rental application ${row.id}`,
    dedup: { column: 'rental_application_id', id: row.id },
  };
}

async function resolveRentalProposalContext(
  connection: PoolClient | typeof pool,
  proposalId: string,
): Promise<ResolvedContext> {
  const proposal = await connection.query<{
    id: string;
    property_id: string | null;
    unit_id: string | null;
    prospective_renter_id: string | null;
    landlord_user_id: string | null;
  }>(
    `SELECT id, property_id, unit_id, prospective_renter_id, landlord_user_id
       FROM rental_proposals WHERE id = $1`,
    [proposalId],
  );
  const row = proposal.rows[0];
  if (!row) throw new NotFoundError('Rental proposal');
  const managers = row.property_id ? await derivePropertyManagers(connection, row.property_id) : [];
  const authorized = new Set<string>(managers);
  if (row.prospective_renter_id) authorized.add(row.prospective_renter_id);
  if (row.landlord_user_id) authorized.add(row.landlord_user_id);
  return {
    type: 'rental_proposal',
    propertyId: row.property_id,
    unitId: row.unit_id,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: row.id,
    siteVisitId: null,
    tenancyId: null,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Rental proposal ${row.id}`,
    dedup: { column: 'rental_proposal_id', id: row.id },
  };
}

/**
 * Authorized provider-side participants for a service-provider resource:
 * the organisation's active owners/admins plus any staff explicitly and
 * actively assigned to this specific resource. A staff member who merely
 * belongs to the organisation (member/staff role, not assigned) is NOT
 * authorized, and revoked staff (is_active = false / removed) are excluded.
 */
async function deriveProviderParticipants(
  connection: PoolClient | typeof pool,
  organisationId: string | null,
  assignedStaffUserIds: string[],
): Promise<string[]> {
  const authorized = new Set<string>(assignedStaffUserIds.filter(Boolean));
  if (organisationId) {
    const owners = await connection.query<{ user_id: string }>(
      `SELECT user_id FROM organisation_members
        WHERE organisation_id = $1 AND status = 'active'
          AND role IN ('owner','admin') AND user_id IS NOT NULL`,
      [organisationId],
    );
    for (const row of owners.rows) authorized.add(row.user_id);
  }
  return [...authorized];
}

async function resolveMarketplaceRequestContext(
  connection: PoolClient | typeof pool,
  requestId: string,
): Promise<ResolvedContext> {
  const req = await connection.query<{
    id: string;
    customer_user_id: string | null;
    title: string | null;
    provider_user_id: string | null;
    provider_organisation_id: string | null;
  }>(
    `SELECT r.id, r.customer_user_id, r.title,
            sp.user_id AS provider_user_id, sp.organisation_id AS provider_organisation_id
       FROM service_requests r
       LEFT JOIN specialized_profiles sp ON sp.id = r.assigned_provider_id
      WHERE r.id = $1`,
    [requestId],
  );
  const row = req.rows[0];
  if (!row) throw new NotFoundError('Service request');
  const providerUsers = await deriveProviderParticipants(
    connection,
    row.provider_organisation_id,
    row.provider_user_id ? [row.provider_user_id] : [],
  );
  const authorized = new Set<string>(providerUsers);
  if (row.customer_user_id) authorized.add(row.customer_user_id);
  return {
    type: 'marketplace_request',
    propertyId: null,
    unitId: null,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    marketplaceRequestId: row.id,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: row.title ? `Service request: ${row.title}` : `Service request ${row.id}`,
    dedup: { column: 'marketplace_request_id', id: row.id },
  };
}

async function resolveMovingJobContext(
  connection: PoolClient | typeof pool,
  jobId: string,
): Promise<ResolvedContext> {
  const job = await connection.query<{
    id: string;
    customer_user_id: string;
    provider_organisation_id: string | null;
    assigned_staff_user_id: string | null;
  }>(
    `SELECT id, customer_user_id, provider_organisation_id, assigned_staff_user_id
       FROM moving_jobs WHERE id = $1`,
    [jobId],
  );
  const row = job.rows[0];
  if (!row) throw new NotFoundError('Moving job');
  const assigned = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM moving_job_staff_assignments WHERE moving_job_id = $1 AND is_active = TRUE`,
    [jobId],
  );
  const staffIds = assigned.rows.map((r) => r.user_id);
  if (row.assigned_staff_user_id) staffIds.push(row.assigned_staff_user_id);
  const providerUsers = await deriveProviderParticipants(connection, row.provider_organisation_id, staffIds);
  const authorized = new Set<string>(providerUsers);
  authorized.add(row.customer_user_id);
  return {
    type: 'moving_job',
    propertyId: null,
    unitId: null,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    movingJobId: row.id,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Moving job ${row.id}`,
    dedup: { column: 'moving_job_id', id: row.id },
  };
}

async function resolveGarbageJobContext(
  connection: PoolClient | typeof pool,
  jobId: string,
): Promise<ResolvedContext> {
  const job = await connection.query<{
    id: string;
    customer_user_id: string;
    provider_organisation_id: string | null;
    assigned_staff_user_id: string | null;
  }>(
    `SELECT id, customer_user_id, provider_organisation_id, assigned_staff_user_id
       FROM garbage_jobs WHERE id = $1`,
    [jobId],
  );
  const row = job.rows[0];
  if (!row) throw new NotFoundError('Garbage job');
  const assigned = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM garbage_job_staff_assignments WHERE garbage_job_id = $1 AND is_active = TRUE`,
    [jobId],
  );
  const staffIds = assigned.rows.map((r) => r.user_id);
  if (row.assigned_staff_user_id) staffIds.push(row.assigned_staff_user_id);
  const providerUsers = await deriveProviderParticipants(connection, row.provider_organisation_id, staffIds);
  const authorized = new Set<string>(providerUsers);
  authorized.add(row.customer_user_id);
  return {
    type: 'garbage_job',
    propertyId: null,
    unitId: null,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    garbageJobId: row.id,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Garbage collection ${row.id}`,
    dedup: { column: 'garbage_job_id', id: row.id },
  };
}

async function resolveLaundryOrderContext(
  connection: PoolClient | typeof pool,
  orderId: string,
): Promise<ResolvedContext> {
  const order = await connection.query<{
    id: string;
    customer_user_id: string;
    provider_organisation_id: string | null;
    assigned_staff_user_id: string | null;
  }>(
    `SELECT id, customer_user_id, provider_organisation_id, assigned_staff_user_id
       FROM laundry_orders WHERE id = $1`,
    [orderId],
  );
  const row = order.rows[0];
  if (!row) throw new NotFoundError('Laundry order');
  const assigned = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM laundry_order_staff_assignments WHERE laundry_order_id = $1 AND is_active = TRUE`,
    [orderId],
  );
  const staffIds = assigned.rows.map((r) => r.user_id);
  if (row.assigned_staff_user_id) staffIds.push(row.assigned_staff_user_id);
  const providerUsers = await deriveProviderParticipants(connection, row.provider_organisation_id, staffIds);
  const authorized = new Set<string>(providerUsers);
  authorized.add(row.customer_user_id);
  return {
    type: 'laundry_order',
    propertyId: null,
    unitId: null,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    laundryOrderId: row.id,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Laundry order ${row.id}`,
    dedup: { column: 'laundry_order_id', id: row.id },
  };
}

async function resolveSchedulingActivityContext(
  connection: PoolClient | typeof pool,
  activityId: string,
): Promise<ResolvedContext> {
  const activity = await connection.query<{
    id: string;
    customer_user_id: string | null;
    provider_organisation_id: string | null;
    domain: string;
  }>(
    `SELECT id, customer_user_id, provider_organisation_id, domain
       FROM scheduling_activities WHERE id = $1`,
    [activityId],
  );
  const row = activity.rows[0];
  if (!row) throw new NotFoundError('Scheduling activity');
  const assigned = await connection.query<{ user_id: string }>(
    `SELECT user_id FROM staff_assignments WHERE activity_id = $1 AND is_active = TRUE`,
    [activityId],
  );
  const staffIds = assigned.rows.map((r) => r.user_id);
  const providerUsers = await deriveProviderParticipants(connection, row.provider_organisation_id, staffIds);
  const authorized = new Set<string>(providerUsers);
  if (row.customer_user_id) authorized.add(row.customer_user_id);
  return {
    type: 'scheduling_activity',
    propertyId: null,
    unitId: null,
    enquiryId: null,
    rentalApplicationId: null,
    rentalProposalId: null,
    siteVisitId: null,
    tenancyId: null,
    schedulingActivityId: row.id,
    authorizedUserIds: [...authorized],
    allowInitiatorJoin: false,
    subject: `Appointment (${row.domain})`,
    dedup: { column: 'scheduling_activity_id', id: row.id },
  };
}

async function resolveContext(
  connection: PoolClient | typeof pool,
  input: StartConversationInput,
): Promise<ResolvedContext> {
  if (input.enquiryId) return resolveEnquiryContext(connection, input.enquiryId);
  if (input.rentalApplicationId) return resolveRentalApplicationContext(connection, input.rentalApplicationId);
  if (input.rentalProposalId) return resolveRentalProposalContext(connection, input.rentalProposalId);
  if (input.siteVisitId) return resolveSiteVisitContext(connection, input.siteVisitId);
  if (input.tenancyId) return resolveTenancyContext(connection, input.tenancyId);
  if (input.marketplaceRequestId) return resolveMarketplaceRequestContext(connection, input.marketplaceRequestId);
  if (input.movingJobId) return resolveMovingJobContext(connection, input.movingJobId);
  if (input.garbageJobId) return resolveGarbageJobContext(connection, input.garbageJobId);
  if (input.laundryOrderId) return resolveLaundryOrderContext(connection, input.laundryOrderId);
  if (input.schedulingActivityId) return resolveSchedulingActivityContext(connection, input.schedulingActivityId);

  // No explicit context row: fall back to a property-scoped, staff-only thread.
  // This requires the requester to be a property manager and limits
  // participants to owners/managers (no arbitrary accounts).
  if (input.propertyId) {
    const managers = await derivePropertyManagers(connection, input.propertyId);
    const property = await connection.query<{ unit_id: string | null }>(
      `SELECT id FROM properties WHERE id = $1`,
      [input.propertyId],
    );
    if (!property.rows[0]) throw new NotFoundError('Property');
    return {
      type: input.type,
      propertyId: input.propertyId,
      unitId: input.unitId ?? null,
      enquiryId: null,
      rentalApplicationId: null,
      rentalProposalId: null,
      siteVisitId: null,
      tenancyId: null,
      authorizedUserIds: managers,
      allowInitiatorJoin: true,
      subject: input.subject ?? null,
      dedup: null,
    };
  }

  throw new ValidationError(
    'A conversation must be started from an enquiry, site visit, tenancy or property context',
  );
}

/**
 * Start (or reuse) an authorized contextual conversation.
 *
 * Security guarantees:
 *  - The requester must be part of the authorized participant universe for the
 *    context (owner / assigned manager / the counterpart).
 *  - Any client-supplied participant ids must be within that universe.
 *  - A caretaker (unit-access only) is never in the universe.
 *  - Duplicate conversations for the same context are reused, not recreated.
 */
export async function startConversation(userId: string, input: StartConversationInput) {
  return repo.dbTransaction(async (client) => {
    const context = await resolveContext(client, input);

    // Serialise concurrent starts for the same context so two "Message" taps
    // cannot create duplicate conversations.
    const lockKey = context.dedup
      ? `${context.dedup.column}:${context.dedup.id}`
      : context.propertyId
        ? `property:${context.propertyId}:${userId}`
        : `subject:${context.subject ?? input.subject ?? 'general'}:${userId}`;
    await client.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [`conversation:${lockKey}`]);

    // Authorize the initiator. For "contact the host" property conversations a
    // prospective renter may start a thread; otherwise the initiator must be
    // part of the context's authorized universe.
    const initiatorAuthorized =
      context.allowInitiatorJoin || context.authorizedUserIds.includes(userId);
    if (!initiatorAuthorized) {
      throw new ForbiddenError(
        'You are not authorized to start a conversation for this context',
      );
    }

    // Validate any suggested counterpart ids against the authorized universe.
    const requested = (input.participantUserIds ?? []).filter((id) => id && id !== userId);
    for (const candidate of requested) {
      if (!context.authorizedUserIds.includes(candidate)) {
        throw new ForbiddenError(
          'One or more participants are not authorized for this conversation',
        );
      }
    }

    const participantIds = [...new Set([...context.authorizedUserIds, userId])];

    // Dedup rules:
    //  - Enquiry / site-visit / tenancy contexts always reuse the active thread.
    //  - Property-only threads are reused only for the "contact the host" flow,
    //    i.e. a non-manager initiator (a prospective renter). A manager opening
    //    several distinct threads on one property is allowed.
    const dedupPropertyContact =
      !context.dedup &&
      context.propertyId !== null &&
      context.allowInitiatorJoin &&
      !context.authorizedUserIds.includes(userId);

    const existing = context.dedup
      ? await repo.findActiveConversationForContext(client, {
          type: context.type,
          column: context.dedup.column,
          id: context.dedup.id,
        })
      : dedupPropertyContact && context.propertyId
        ? await repo.findActivePropertyConversation(client, context.propertyId, userId)
        : undefined;

    if (existing) {
      let firstMessage: repo.MessageRow | null = null;
      if (input.message && input.message.trim().length > 0) {
        await repo.assertActiveParticipant(client, existing.id, userId);
        firstMessage = await repo.insertMessage({
          conversationId: existing.id,
          senderId: userId,
          content: input.message.trim(),
          client,
        });
        await enqueueNewMessageOutbox(client, existing, userId, firstMessage);
      }
      return { conversation: existing, firstMessage, reused: true };
    }

    if (input.message && input.message.trim().length > MAX_MESSAGE_LENGTH) {
      throw new ValidationError(`Message must be at most ${MAX_MESSAGE_LENGTH} characters`);
    }

    const { conversation, firstMessage } = await repo.insertConversationWithMessage({
      type: context.type,
      subject: input.subject ?? context.subject,
      propertyId: context.propertyId,
      unitId: context.unitId,
      enquiryId: context.enquiryId,
      rentalApplicationId: context.rentalApplicationId,
      rentalProposalId: context.rentalProposalId,
      siteVisitId: context.siteVisitId,
      tenancyId: context.tenancyId,
      movingJobId: context.movingJobId ?? null,
      marketplaceRequestId: context.marketplaceRequestId ?? null,
      garbageJobId: context.garbageJobId ?? null,
      laundryOrderId: context.laundryOrderId ?? null,
      schedulingActivityId: context.schedulingActivityId ?? null,
      participantUserIds: participantIds.filter((id) => id !== userId),
      createdBy: userId,
      firstMessage: input.message ?? null,
    });

    if (firstMessage) {
      await enqueueNewMessageOutbox(client, conversation, userId, firstMessage);
    }

    return { conversation, firstMessage, reused: false };
  });
}

// ---------------------------------------------------------------------------
// Read-side operations
// ---------------------------------------------------------------------------
export async function listMyConversations(userId: string, options: {
  status?: string;
  type?: string;
  propertyId?: string;
  search?: string;
  limit: number;
  offset: number;
}): Promise<{ items: ConversationListItem[]; total: number; limit: number; offset: number }> {
  const { items, total } = await repo.listConversationsForUser(userId, options);
  return { items, total, limit: options.limit, offset: options.offset };
}

export async function getMyConversation(userId: string, conversationId: string) {
  const conversation = await repo.getConversation(pool, conversationId);
  if (!conversation) throw new NotFoundError('Conversation');
  await repo.assertActiveParticipant(pool, conversationId, userId);
  const [participants, unreadCount] = await Promise.all([
    repo.listParticipants(pool, conversationId),
    repo.getConversationUnreadCount(conversationId, userId),
  ]);
  return { conversation, participants, unreadCount };
}

export async function getMyUnreadCount(userId: string): Promise<{ unreadCount: number }> {
  return { unreadCount: await repo.getTotalUnreadCount(userId) };
}

export async function listMyMessages(
  userId: string,
  conversationId: string,
  options: { before?: repo.MessageCursor | null; limit: number },
): Promise<{ items: MessageListItem[]; hasMore: boolean }> {
  await repo.assertActiveParticipant(pool, conversationId, userId);
  return repo.listMessages(conversationId, userId, options);
}

// ---------------------------------------------------------------------------
// Send message (transactional message + outbox notification).
// ---------------------------------------------------------------------------
export async function sendMessage(
  userId: string,
  input: { conversationId: string; content: string; type?: string; replyToId?: string | null },
): Promise<MessageListItem> {
  const content = input.content?.trim() ?? '';
  if (!content) throw new ValidationError('Message content is required');
  if (content.length > MAX_MESSAGE_LENGTH) {
    throw new ValidationError(`Message must be at most ${MAX_MESSAGE_LENGTH} characters`);
  }

  return repo.dbTransaction(async (client) => {
    const conversation = await repo.getConversation(client, input.conversationId);
    if (!conversation) throw new NotFoundError('Conversation');
    await repo.assertActiveParticipant(client, input.conversationId, userId);

    if (input.replyToId) {
      const parent = await repo.getMessageById(client, input.replyToId);
      if (!parent || parent.conversationId !== input.conversationId) {
        throw new ValidationError('Reply target is not in this conversation');
      }
    }

    const message = await repo.insertMessage({
      conversationId: input.conversationId,
      senderId: userId,
      content,
      type: input.type ?? 'text',
      replyToId: input.replyToId ?? null,
      client,
    });

    await enqueueNewMessageOutbox(client, conversation, userId, message);

    return {
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      type: message.type,
      content: message.content,
      status: message.status,
      replyToId: message.replyToId,
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
      deletedAt: message.deletedAt,
      isRead: false,
      attachments: [],
    };
  });
}

async function enqueueNewMessageOutbox(
  client: PoolClient,
  conversation: ConversationRow,
  senderId: string,
  message: repo.MessageRow,
): Promise<void> {
  const recipients = (await repo.getParticipantUserIds(client, conversation.id)).filter(
    (id) => id !== senderId,
  );
  if (recipients.length === 0) return;

  const preview = message.content.length > 120 ? `${message.content.slice(0, 117)}...` : message.content;

  await notifications.createOutboxEvent({
    idempotencyKey: `message.created:${message.id}`,
    eventType: 'message.created',
    category: 'operational',
    priority: 'normal',
    recipientUserIds: recipients,
    organisationId: null,
    resourceType: 'conversation',
    resourceId: conversation.id,
    payload: {
      conversationId: conversation.id,
      messageId: message.id,
      senderId,
      preview,
      subject: conversation.subject,
      propertyId: conversation.propertyId,
    },
    channels: ['in_app', 'push', 'email'],
  });
}

// ---------------------------------------------------------------------------
// Read-state
// ---------------------------------------------------------------------------
export async function markConversationRead(userId: string, conversationId: string): Promise<{ marked: number }> {
  await repo.assertActiveParticipant(pool, conversationId, userId);
  const marked = await repo.dbTransaction((client) =>
    repo.markConversationRead(client, conversationId, userId),
  );
  return { marked };
}

export async function markMessageRead(userId: string, messageId: string): Promise<{ marked: boolean }> {
  await repo.dbTransaction(async (client) => {
    const message = await repo.getMessageById(client, messageId);
    if (!message) throw new NotFoundError('Message');
    await repo.assertActiveParticipant(client, message.conversationId, userId);
    await repo.markMessageRead(client, messageId, userId);
  });
  return { marked: true };
}

// ---------------------------------------------------------------------------
// Archive / reopen
// ---------------------------------------------------------------------------
export async function archiveConversation(userId: string, conversationId: string) {
  await repo.assertActiveParticipant(pool, conversationId, userId);
  const updated = await repo.setConversationArchived(conversationId, true);
  if (!updated) throw new NotFoundError('Conversation');
  return updated;
}

export async function reopenConversation(userId: string, conversationId: string) {
  await repo.assertActiveParticipant(pool, conversationId, userId);
  const updated = await repo.setConversationArchived(conversationId, false);
  if (!updated) throw new NotFoundError('Conversation');
  return updated;
}

// ---------------------------------------------------------------------------
// Attachment download authorization. Returns the storage key only when the
// requesting user is an active participant of the attachment's conversation.
// ---------------------------------------------------------------------------
export async function getAttachmentForDownload(
  userId: string,
  attachmentId: string,
): Promise<{ attachment: AttachmentRow; conversationId: string }> {
  const attachment = await repo.getAttachment(pool, attachmentId);
  if (!attachment) throw new NotFoundError('Attachment');
  const message = await repo.getMessageById(pool, attachment.messageId);
  if (!message) throw new NotFoundError('Attachment');
  await repo.assertActiveParticipant(pool, message.conversationId, userId);
  return { attachment, conversationId: message.conversationId };
}

export { MAX_MESSAGE_LENGTH };