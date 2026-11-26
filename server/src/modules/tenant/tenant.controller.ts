// Tenant controller — tenant-facing HTTP handlers scoped to the
// authenticated user's tenancy relationships.
import type { Request, Response } from 'express';
import {
  NotFoundError,
  ForbiddenError,
  ValidationError,
} from '../../shared/errors.js';
import type { AuthUser } from '../auth/auth.types.js';
import * as repo from './tenant.repository.js';
import * as authz from '../auth/authorization.service.js';
import * as signedUrlService from '../auth/document-signed-url.service.js';
import {
  enqueueOutboxEventTransactional,
  classifyEventType,
} from '../auth/transactional-outbox.service.js';
import type { PoolClient } from 'pg';
import { pool } from '../../db/pool.js';

interface AuthenticatedRequest extends Request {
  user?: AuthUser;
}

function assertAuth(req: AuthenticatedRequest) {
  if (!req.user) throw new ForbiddenError('Authentication required');
  return req.user.id;
}

async function assertTenancyAccess(req: AuthenticatedRequest, tenancyId: string) {
  const userId = assertAuth(req);
  const decision = await authz.canAccessTenancy(userId, tenancyId);
  if (!decision.allowed) throw new ForbiddenError(decision.reason);
  return decision;
}

/**
 * GET /api/v1/tenant/dashboard
 * Aggregated tenant dashboard data.
 */
export async function getTenantDashboard(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);

  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }

  let activeTenancy: repo.TenancyRecord | null = null;
  let property: repo.PropertySummary | null = null;
  let unit: repo.UnitSummary | null = null;
  let outstandingBalance: number | null = null;
  let invoiceCount = 0;

  if (tenant.tenancyId) {
    const foundTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
    activeTenancy = foundTenancy ?? null;
    if (activeTenancy) {
      const foundProperty = await repo.findPropertyByIdForTenant(activeTenancy.propertyId);
      property = foundProperty ?? null;
      if (activeTenancy.unitId) {
        const foundUnit = await repo.findUnitByIdForTenant(activeTenancy.unitId);
        unit = foundUnit ?? null;
        outstandingBalance = await repo.findOutstandingBalance(activeTenancy.unitId);
        invoiceCount = await repo.findInvoiceCount(activeTenancy.unitId);
      }
    }
  }

  const historicalTenancies = await repo.findTenanciesByTenantId(tenant.id);
  const unreadCount = await repo.findUnreadNotificationCount(userId);

  const dashboard: repo.TenantDashboardData = {
    tenant,
    activeTenancy,
    property,
    unit,
    historicalTenancies: historicalTenancies.filter(
      (t) => t.status !== 'active',
    ),
    invoiceCount,
    outstandingBalance,
    unreadNotificationCount: unreadCount,
  };

  res.json({ success: true, data: dashboard });
}

/**
 * GET /api/v1/tenant/tenancies
 * List all tenancies for the authenticated tenant.
 */
export async function getTenantTenancies(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }

  const { status } = req.query;
  const tenancies = await repo.findTenanciesByTenantId(tenant.id);

  const filtered = status
    ? tenancies.filter((t) => t.status === status)
    : tenancies;

  res.json({ success: true, data: filtered });
}

/**
 * GET /api/v1/tenant/tenancies/:tenancyId
 * Get a single tenancy the tenant is authorized to view.
 */
export async function getTenantTenancyDetail(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenancyIdParam = req.params.tenancyId;
  const tenancyId = Array.isArray(tenancyIdParam) ? tenancyIdParam[0] : tenancyIdParam;
  if (!tenancyId) {
    throw new NotFoundError('Tenancy not found');
  }

  await assertTenancyAccess(req, tenancyId);

  const result = await (import('../auth/auth.repository.js')).then((m) =>
    m.findTenancyById(tenancyId),
  );
  if (!result) throw new NotFoundError('Tenancy not found');

  const property = await repo.findPropertyByIdForTenant(result.propertyId);
  let unit: repo.UnitSummary | null = null;
  if (result.unitId) {
    const foundUnit = await repo.findUnitByIdForTenant(result.unitId);
    unit = foundUnit ?? null;
  }

  res.json({
    success: true,
    data: { tenancy: result, property, unit },
  });
}

/**
 * GET /api/v1/tenant/invoices
 * List invoices for the tenant's active unit.
 */
export async function getTenantInvoices(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant || !tenant.tenancyId) {
    res.json({ success: true, data: [] });
    return;
  }

  const activeTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy || !activeTenancy.unitId) {
    res.json({ success: true, data: [] });
    return;
  }

  await assertTenancyAccess(req, activeTenancy.id);

  const { pool } = await import('../../db/pool.js');
  const result = await pool.query(
    `SELECT id, unit_id AS "unitId", invoice_number AS "invoiceNumber",
            status, total_amount AS "totalAmount", currency,
            due_date AS "dueDate",
            COALESCE(issued_at, created_at) AS "issuedAt",
            amount_paid AS "amountPaid",
            amount_outstanding AS "amountOutstanding",
            description
     FROM invoices
     WHERE tenancy_id = $1 AND status NOT IN ('cancelled', 'void')
     ORDER BY COALESCE(issued_at, created_at) DESC`,
    [activeTenancy.id],
  );
  res.json({ success: true, data: result.rows });
}

/**
 * GET /api/v1/tenant/invoices/:invoiceId
 * Get a single invoice with its line items, scoped to the tenant's tenancy.
 */
export async function getTenantInvoiceDetail(
  req: AuthenticatedRequest,
  res: Response,
) {
  const userId = assertAuth(req);
  const invoiceId = req.params.invoiceId;
  const id = Array.isArray(invoiceId) ? invoiceId[0] : invoiceId;
  if (!id) throw new NotFoundError('Invoice not found');

  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant || !tenant.tenancyId) {
    throw new NotFoundError('No active tenant record found for this user');
  }
  const activeTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy) {
    throw new ForbiddenError('No active tenancy found for this tenant');
  }
  await assertTenancyAccess(req, activeTenancy.id);

  const { pool } = await import('../../db/pool.js');
  const invoice = await pool.query(
    `SELECT id, unit_id as "unitId", invoice_number as "invoiceNumber",
            status, total_amount as "totalAmount", currency,
            due_date as "dueDate", created_at as "issuedAt",
            amount_paid as "amountPaid", amount_outstanding as "amountOutstanding",
            notes, created_at as "createdAt"
     FROM invoices WHERE id = $1 AND tenancy_id = $2`,
    [id, activeTenancy.id],
  );
  const row = invoice.rows[0];
  if (!row) throw new NotFoundError('Invoice not found');

  const items = await pool.query(
    `SELECT id, charge_type as "chargeType", description, amount, currency,
            billing_period_start as "billingPeriodStart",
            billing_period_end as "billingPeriodEnd", quantity, unit_price as "unitPrice",
            created_at as "createdAt"
     FROM invoice_items WHERE invoice_id = $1
     ORDER BY created_at`,
    [id],
  );

  res.json({
    success: true,
    data: { ...row, lineItems: items.rows },
  });
}

/**
 * GET /api/v1/tenant/payments
 * List payments for the tenant's active unit.
 */
export async function getTenantPayments(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant || !tenant.tenancyId) {
    res.json({ success: true, data: [] });
    return;
  }

  const activeTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy || !activeTenancy.unitId) {
    res.json({ success: true, data: [] });
    return;
  }

  await assertTenancyAccess(req, activeTenancy.id);

  const { pool } = await import('../../db/pool.js');
  const result = await pool.query(
    `SELECT pt.id, pt.invoice_id AS "invoiceId", pt.amount, pt.currency,
            pt.provider AS "paymentMethod",
            COALESCE(pt.provider_transaction_id, pt.transaction_reference, '') AS "paymentReference",
            pt.status,
            pt.payment_date AS "paidAt",
            pt.created_at AS "createdAt"
     FROM payment_transactions pt
     JOIN invoices i ON i.id = pt.invoice_id
     WHERE i.tenancy_id = $1
     ORDER BY pt.payment_date DESC NULLS LAST, pt.created_at DESC`,
    [activeTenancy.id],
  );
  res.json({ success: true, data: result.rows });
}

/**
 * GET /api/v1/tenant/maintenance-requests
 * List maintenance issues for the tenant's unit.
 */
export async function getTenantMaintenanceRequests(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant || !tenant.tenancyId) {
    res.json({ success: true, data: [] });
    return;
  }

  const activeTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy || !activeTenancy.unitId) {
    res.json({ success: true, data: [] });
    return;
  }

  await assertTenancyAccess(req, activeTenancy.id);

  const { pool } = await import('../../db/pool.js');
  const result = await pool.query(
    `SELECT id, unit_id as "unitId", category, urgency, status,
            description, photos, assigned_to_user_id as "assignedToUserId",
            resolved_at as "resolvedAt", created_at as "createdAt",
            updated_at as "updatedAt"
     FROM issues WHERE unit_id = $1
     ORDER BY created_at DESC`,
    [activeTenancy.unitId],
  );
  res.json({ success: true, data: result.rows });
}

/**
 * GET /api/v1/tenant/garbage-requests
 * List garbage collection requests for the tenant's unit.
 */
export async function getTenantGarbageRequests(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant || !tenant.tenancyId) {
    res.json({ success: true, data: [], pagination: { limit: 20, offset: 0, total: 0 } });
    return;
  }

  const activeTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy || !activeTenancy.unitId) {
    res.json({ success: true, data: [], pagination: { limit: 20, offset: 0, total: 0 } });
    return;
  }

  await assertTenancyAccess(req, activeTenancy.id);

  const query = req.query as { status?: string; limit?: number; offset?: number };
  const result = await repo.listGarbageRequestsByUnit(activeTenancy.unitId, {
    status: query.status,
    limit: query.limit ?? 20,
    offset: query.offset ?? 0,
  });
  res.json({
    success: true,
    data: result.rows,
    pagination: { limit: query.limit ?? 20, offset: query.offset ?? 0, total: result.total },
  });
}

/**
 * GET /api/v1/tenant/moving-requests
 * List moving service requests owned by the authenticated tenant.
 */
export async function getTenantMovingRequests(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    res.json({ success: true, data: [], pagination: { limit: 20, offset: 0, total: 0 } });
    return;
  }

  const query = req.query as { status?: string; limit?: number; offset?: number };
  const result = await repo.listMovingRequestsByTenant(tenant.id, {
    status: query.status,
    limit: query.limit ?? 20,
    offset: query.offset ?? 0,
  });
  res.json({
    success: true,
    data: result.rows,
    pagination: { limit: query.limit ?? 20, offset: query.offset ?? 0, total: result.total },
  });
}

/**
 * GET /api/v1/tenant/laundry-requests
 * List laundry service requests owned by the authenticated tenant.
 */
export async function getTenantLaundryRequests(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    res.json({ success: true, data: [], pagination: { limit: 20, offset: 0, total: 0 } });
    return;
  }

  const query = req.query as { status?: string; limit?: number; offset?: number };
  const result = await repo.listLaundryRequestsByTenant(tenant.id, {
    status: query.status,
    limit: query.limit ?? 20,
    offset: query.offset ?? 0,
  });
  res.json({
    success: true,
    data: result.rows,
    pagination: { limit: query.limit ?? 20, offset: query.offset ?? 0, total: result.total },
  });
}

/**
 * GET /api/v1/tenant/documents/signed-url
 * Get a short-lived signed URL for a document the tenant is authorized to access.
 */
export async function getDocumentSignedUrl(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const { documentId, purpose, ttlSeconds } = req.body;

  const result = await signedUrlService.generateDocumentSignedUrl(
    documentId,
    userId,
    purpose,
    ttlSeconds,
  );
  if (!result) {
    throw new NotFoundError('Document not found or access denied');
  }

  res.json({ success: true, data: result });
}

/**
 * Get property managers/owners for outbox notification recipients.
 */
async function getPropertyManagers(client: PoolClient, propertyId: string): Promise<string[]> {
  const result = await client.query<{ user_id: string }>(
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

/**
 * Helper: resolve the authenticated tenant and their active tenancy/unit.
 */
async function resolveTenantTenancy(req: AuthenticatedRequest) {
  const userId = assertAuth(req);
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }
  if (!tenant.tenancyId) {
    throw new ForbiddenError('No active tenancy found for this tenant');
  }
  const activeTenancy = await repo.findActiveTenancyByTenantId(tenant.id);
  if (!activeTenancy) {
    throw new ForbiddenError('No active tenancy found for this tenant');
  }
  await assertTenancyAccess(req, activeTenancy.id);
  return { userId, tenant, activeTenancy };
}

/**
 * POST /api/v1/tenant/maintenance-requests
 * Tenant submits a maintenance issue for their unit.
 */
export async function createTenantMaintenanceRequest(req: AuthenticatedRequest, res: Response) {
  const { userId, tenant, activeTenancy } = await resolveTenantTenancy(req);
  const data = req.body as {
    unitId: string;
    title: string;
    category: string;
    priority: string;
    description: string;
    photos?: string[];
    accessInstructions?: string | null;
    preferredAvailability?: string | null;
  };

  // Validate the unit matches the tenant's active tenancy
  if (data.unitId !== activeTenancy.unitId) {
    throw new ForbiddenError('Unit does not belong to your active tenancy');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const issue = await repo.createMaintenanceRequest({
      propertyId: activeTenancy.propertyId,
      unitId: activeTenancy.unitId!,
      tenancyId: activeTenancy.id,
      reporterId: userId,
      title: data.title,
      description: data.description,
      category: data.category,
      priority: data.priority,
      photos: data.photos ?? [],
      accessInstructions: data.accessInstructions ?? null,
      preferredAvailability: data.preferredAvailability ? new Date(data.preferredAvailability) : null,
    });

    // Transactional outbox event for new maintenance request
    const managers = await getPropertyManagers(client, activeTenancy.propertyId);
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `maintenance_request.created:${issue.id}`,
      eventType: 'maintenance_request.created',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: managers,
      organisationId: null,
      resourceType: 'maintenance_request',
      resourceId: issue.id,
      payload: {
        requestId: issue.id,
        unitId: issue.unitId,
        category: issue.category,
        priority: issue.priority,
        status: issue.status,
        createdAt: issue.createdAt,
      },
      channels: ['in_app'],
      classification: 'critical',
    });

    await client.query('COMMIT');
    res.status(201).json({ success: true, data: issue });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * POST /api/v1/tenant/garbage-requests
 * Tenant submits a garbage collection request.
 */
export async function createTenantGarbageRequest(req: AuthenticatedRequest, res: Response) {
  const { userId, tenant, activeTenancy } = await resolveTenantTenancy(req);
  const data = req.body as {
    unitId: string;
    category: string;
    description: string;
    preferredDate?: string | null;
  };

  if (data.unitId !== activeTenancy.unitId) {
    throw new ForbiddenError('Unit does not belong to your active tenancy');
  }

  // Resolve the garbage provider assignment for this property/unit
  const assignment = await repo.findGarbageProviderAssignmentForUnit(
    activeTenancy.propertyId,
    activeTenancy.unitId ?? null,
  );
  if (!assignment) {
    throw new ForbiddenError('No active garbage service assignment for this property');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const request = await repo.createGarbageRequest({
      propertyId: activeTenancy.propertyId,
      unitId: activeTenancy.unitId!,
      garbageProviderId: assignment.garbageProviderId,
      requestType: data.category,
      notes: data.description,
      createdBy: userId,
    });

    const managers = await getPropertyManagers(client, activeTenancy.propertyId);
    const recipients = [...new Set([...managers, assignment.garbageProviderId])];
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `garbage_request.created:${request.id}`,
      eventType: 'garbage_request.created',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: recipients,
      organisationId: null,
      resourceType: 'garbage_request',
      resourceId: request.id,
      payload: {
        requestId: request.id,
        unitId: request.unitId,
        category: request.requestType,
        status: request.status,
        providerId: request.garbageProviderId,
        createdAt: request.createdAt,
      },
      channels: ['in_app'],
      classification: 'critical',
    });

    await client.query('COMMIT');
    res.status(201).json({ success: true, data: request });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * POST /api/v1/tenant/moving-requests
 * Tenant submits a moving service request.
 */
export async function createTenantMovingRequest(req: AuthenticatedRequest, res: Response) {
  const { userId, tenant, activeTenancy } = await resolveTenantTenancy(req);
  const data = req.body as {
    pickupUnitId: string;
    destinationAddress: string;
    preferredDateTime: string;
    itemDescription: string;
    specialInstructions?: string | null;
    providerId?: string | null;
    contactName?: string | null;
    contactPhone?: string | null;
    contactEmail?: string | null;
  };

  if (data.pickupUnitId !== activeTenancy.unitId) {
    throw new ForbiddenError('Pickup unit does not belong to your active tenancy');
  }

  // Validate provider exists and is a moving service provider if specified
  if (data.providerId) {
    const provider = await clientQuery(
      `SELECT id FROM specialized_profiles WHERE id = $1 AND profile_category = 'moving_service_provider'`,
      [data.providerId],
    );
    if (provider.rows.length === 0) {
      throw new NotFoundError('Moving provider not found');
    }
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const request = await repo.createMovingRequest({
      propertyId: activeTenancy.propertyId,
      unitId: activeTenancy.unitId!,
      tenancyId: activeTenancy.id,
      tenantId: tenant.id,
      providerId: data.providerId ?? null,
      serviceType: 'other',
      pickupLocation: `Unit ${activeTenancy.unitId}`,
      destinationLocation: data.destinationAddress,
      pickupLatitude: null,
      pickupLongitude: null,
      destinationLatitude: null,
      destinationLongitude: null,
      preferredDateTime: data.preferredDateTime ? new Date(data.preferredDateTime) : null,
      itemDescription: data.itemDescription,
      specialInstructions: data.specialInstructions ?? null,
      contactName: data.contactName ?? null,
      contactPhone: data.contactPhone ?? null,
      contactEmail: data.contactEmail ?? null,
      createdBy: userId,
    });

    const managers = await getPropertyManagers(client, activeTenancy.propertyId);
    const recipients = data.providerId
      ? [...new Set([...managers, data.providerId])]
      : managers;
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `moving_request.created:${request.id}`,
      eventType: 'moving_request.created',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: recipients,
      organisationId: null,
      resourceType: 'moving_request',
      resourceId: request.id,
      payload: {
        requestId: request.id,
        unitId: request.unitId,
        serviceType: request.serviceType,
        status: request.status,
        providerId: request.providerId,
        preferredDateTime: request.preferredDateTime,
        createdAt: request.createdAt,
      },
      channels: ['in_app'],
      classification: 'critical',
    });

    await client.query('COMMIT');
    res.status(201).json({ success: true, data: request });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * POST /api/v1/tenant/laundry-requests
 * Tenant submits a laundry service request.
 */
export async function createTenantLaundryRequest(req: AuthenticatedRequest, res: Response) {
  const { userId, tenant, activeTenancy } = await resolveTenantTenancy(req);
  const data = req.body as {
    providerId: string;
    serviceCategory: string;
    collectionPreference: string;
    preferredDateTime: string;
    garmentCount: number;
    specialInstructions?: string | null;
    contactName?: string | null;
    contactPhone?: string | null;
    contactEmail?: string | null;
  };

  if (!activeTenancy.unitId) {
    throw new ForbiddenError('No unit associated with your active tenancy');
  }

  // Validate provider exists and is a laundry service provider
  const provider = await clientQuery(
    `SELECT id FROM specialized_profiles WHERE id = $1 AND profile_category = 'laundry_service_provider'`,
    [data.providerId],
  );
  if (provider.rows.length === 0) {
    throw new NotFoundError('Laundry provider not found');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const request = await repo.createLaundryRequest({
      propertyId: activeTenancy.propertyId,
      unitId: activeTenancy.unitId,
      tenancyId: activeTenancy.id,
      tenantId: tenant.id,
      providerId: data.providerId,
      serviceCategory: data.serviceCategory,
      collectionPreference: data.collectionPreference,
      preferredDateTime: data.preferredDateTime ? new Date(data.preferredDateTime) : null,
      garmentCount: data.garmentCount,
      specialInstructions: data.specialInstructions ?? null,
      contactName: data.contactName ?? null,
      contactPhone: data.contactPhone ?? null,
      contactEmail: data.contactEmail ?? null,
      createdBy: userId,
    });

    const managers = await getPropertyManagers(client, activeTenancy.propertyId);
    const recipients = [...new Set([...managers, data.providerId])];
    await enqueueOutboxEventTransactional(client, {
      idempotencyKey: `laundry_request.created:${request.id}`,
      eventType: 'laundry_request.created',
      category: 'operational',
      priority: 'normal',
      recipientUserIds: recipients,
      organisationId: null,
      resourceType: 'laundry_request',
      resourceId: request.id,
      payload: {
        requestId: request.id,
        unitId: request.unitId,
        serviceCategory: request.serviceCategory,
        status: request.status,
        providerId: request.providerId,
        preferredDateTime: request.preferredDateTime,
        createdAt: request.createdAt,
      },
      channels: ['in_app'],
      classification: 'critical',
    });

    await client.query('COMMIT');
    res.status(201).json({ success: true, data: request });
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

/**
 * DELETE /api/v1/tenant/maintenance-requests/:requestId
 * Cancel a maintenance request owned by the tenant.
 */
export async function cancelTenantMaintenanceRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const { requestId } = req.params as { requestId: string };
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }

  const issue = await repo.findMaintenanceRequestById(requestId);
  if (!issue) {
    throw new NotFoundError('Maintenance request not found');
  }
  if (issue.reporterId !== userId) {
    throw new ForbiddenError('You can only cancel your own maintenance requests');
  }

  const updated = await repo.cancelMaintenanceRequest(requestId, userId, 'Cancelled by tenant');
  if (!updated) {
    throw new ForbiddenError('Maintenance request cannot be cancelled');
  }
  res.json({ success: true, data: updated });
}

/**
 * DELETE /api/v1/tenant/garbage-requests/:requestId
 * Cancel a garbage request owned by the tenant.
 */
export async function cancelTenantGarbageRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const { requestId } = req.params as { requestId: string };
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }

  const request = await repo.findGarbageRequestById(requestId);
  if (!request) {
    throw new NotFoundError('Garbage request not found');
  }
  if (request.createdBy !== userId) {
    throw new ForbiddenError('You can only cancel your own garbage requests');
  }

  const updated = await repo.cancelGarbageRequest(requestId, userId);
  if (!updated) {
    throw new ForbiddenError('Garbage request cannot be cancelled');
  }
  res.json({ success: true, data: updated });
}

/**
 * DELETE /api/v1/tenant/moving-requests/:requestId
 * Cancel a moving request owned by the tenant.
 */
export async function cancelTenantMovingRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const { requestId } = req.params as { requestId: string };
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }

  const request = await repo.findMovingRequestById(requestId);
  if (!request) {
    throw new NotFoundError('Moving request not found');
  }
  if (request.tenantId !== tenant.id) {
    throw new ForbiddenError('You can only cancel your own moving requests');
  }

  const updated = await repo.cancelMovingRequest(requestId, tenant.id, userId, 'Cancelled by tenant');
  if (!updated) {
    throw new ForbiddenError('Moving request cannot be cancelled');
  }
  res.json({ success: true, data: updated });
}

/**
 * DELETE /api/v1/tenant/laundry-requests/:requestId
 * Cancel a laundry request owned by the tenant.
 */
export async function cancelTenantLaundryRequest(req: AuthenticatedRequest, res: Response) {
  const userId = assertAuth(req);
  const { requestId } = req.params as { requestId: string };
  const tenant = await repo.findTenantByUserId(userId);
  if (!tenant) {
    throw new NotFoundError('No active tenant record found for this user');
  }

  const request = await repo.findLaundryRequestById(requestId);
  if (!request) {
    throw new NotFoundError('Laundry request not found');
  }
  if (request.tenantId !== tenant.id) {
    throw new ForbiddenError('You can only cancel your own laundry requests');
  }

  const updated = await repo.cancelLaundryRequest(requestId, tenant.id, userId, 'Cancelled by tenant');
  if (!updated) {
    throw new ForbiddenError('Laundry request cannot be cancelled');
  }
  res.json({ success: true, data: updated });
}

function clientQuery(sql: string, params: unknown[]) {
  return pool.query(sql, params);
}
