// Tenant repository — database queries scoped to the authenticated user's
// tenancy relationships. Reuses the existing pg pool and raw-query conventions.
import { pool } from '../../db/pool.js';

export type TenantRecord = {
  id: string;
  userId: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  fullName: string;
  email: string | null;
  phone: string | null;
  idNumber: string | null;
  idType: string | null;
  status: string;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type TenancyRecord = {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyType: string;
  status: string;
  startDate: Date | null;
  endDate: Date | null;
  rentAmount: number | null;
  depositAmount: number | null;
  depositHeldBy: string | null;
  depositSchemeReference: string | null;
  rentDueDay: number | null;
  paymentMethod: string | null;
  paymentReference: string | null;
  termsDocumentUrl: string | null;
  specialConditions: string | null;
  managedByUserId: string | null;
  managedByOrganisationId: string | null;
  createdBy: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type PropertySummary = {
  id: string;
  title: string;
  propertyType: string;
  address: string;
  city: string;
  county: string;
  country: string;
  status: string;
};

export type UnitSummary = {
  id: string;
  unitNumber: string;
  unitType: string;
  bedrooms: number | null;
  bathrooms: number | null;
  areaSqm: number | null;
  rentAmount: number | null;
  depositAmount: number | null;
  status: string;
};

export type TenantDashboardData = {
  tenant: TenantRecord | null;
  activeTenancy: TenancyRecord | null;
  property: PropertySummary | null;
  unit: UnitSummary | null;
  historicalTenancies: TenancyRecord[];
  invoiceCount: number;
  outstandingBalance: number | null;
  unreadNotificationCount: number;
};

export async function findTenantByUserId(userId: string): Promise<TenantRecord | undefined> {
  const result = await pool.query<TenantRecord>(
    `SELECT id, user_id as "userId", property_id as "propertyId",
            unit_id as "unitId", tenancy_id as "tenancyId", full_name as "fullName",
            email, phone, id_number as "idNumber", id_type as "idType",
            status, notes, created_at as "createdAt", updated_at as "updatedAt"
     FROM tenants WHERE user_id = $1 AND status = 'active'
     ORDER BY created_at DESC LIMIT 1`,
    [userId],
  );
  return result.rows[0];
}

export async function findTenantsByUserId(userId: string): Promise<TenantRecord[]> {
  const result = await pool.query<TenantRecord>(
    `SELECT id, user_id as "userId", property_id as "propertyId",
            unit_id as "unitId", tenancy_id as "tenancyId", full_name as "fullName",
            email, phone, id_number as "idNumber", id_type as "idType",
            status, notes, created_at as "createdAt", updated_at as "updatedAt"
     FROM tenants WHERE user_id = $1
     ORDER BY created_at DESC`,
    [userId],
  );
  return result.rows;
}

export async function findActiveTenancyByTenantId(tenantId: string): Promise<TenancyRecord | undefined> {
  const result = await pool.query<TenancyRecord>(
    `SELECT t.id, t.property_id as "propertyId", t.unit_id as "unitId",
            t.tenancy_type as "tenancyType", t.status,
            t.start_date as "startDate", t.end_date as "endDate",
            t.rent_amount as "rentAmount", t.deposit_amount as "depositAmount",
            t.deposit_held_by as "depositHeldBy",
            t.deposit_scheme_reference as "depositSchemeReference",
            t.rent_due_day as "rentDueDay",
            t.payment_method as "paymentMethod",
            t.payment_reference as "paymentReference",
            t.terms_document_url as "termsDocumentUrl",
            t.special_conditions as "specialConditions",
            t.managed_by_user_id as "managedByUserId",
            t.managed_by_organisation_id as "managedByOrganisationId",
            t.created_by as "createdBy",
            t.created_at as "createdAt", t.updated_at as "updatedAt"
     FROM tenancies t
     JOIN tenants te ON te.tenancy_id = t.id
     WHERE te.id = $1 AND t.status = 'active'
     ORDER BY t.created_at DESC LIMIT 1`,
    [tenantId],
  );
  return result.rows[0];
}

export async function findTenanciesByTenantId(tenantId: string): Promise<TenancyRecord[]> {
  const result = await pool.query<TenancyRecord>(
    `SELECT t.id, t.property_id as "propertyId", t.unit_id as "unitId",
            t.tenancy_type as "tenancyType", t.status,
            t.start_date as "startDate", t.end_date as "endDate",
            t.rent_amount as "rentAmount", t.deposit_amount as "depositAmount",
            t.deposit_held_by as "depositHeldBy",
            t.deposit_scheme_reference as "depositSchemeReference",
            t.rent_due_day as "rentDueDay",
            t.payment_method as "paymentMethod",
            t.payment_reference as "paymentReference",
            t.terms_document_url as "termsDocumentUrl",
            t.special_conditions as "specialConditions",
            t.managed_by_user_id as "managedByUserId",
            t.managed_by_organisation_id as "managedByOrganisationId",
            t.created_by as "createdBy",
            t.created_at as "createdAt", t.updated_at as "updatedAt"
     FROM tenancies t
     JOIN tenants te ON te.tenancy_id = t.id
     WHERE te.id = $1
     ORDER BY t.created_at DESC`,
    [tenantId],
  );
  return result.rows;
}

export async function findPropertyByIdForTenant(propertyId: string): Promise<PropertySummary | undefined> {
  const result = await pool.query<PropertySummary>(
    `SELECT id, title, property_type as "propertyType", address, city, county, country, status
     FROM properties WHERE id = $1`,
    [propertyId],
  );
  return result.rows[0];
}

export async function findUnitByIdForTenant(unitId: string): Promise<UnitSummary | undefined> {
  const result = await pool.query<UnitSummary>(
    `SELECT id, unit_number as "unitNumber", unit_type as "unitType",
            bedrooms, bathrooms, area_sqm as "areaSqm",
            rent_amount as "rentAmount", deposit_amount as "depositAmount", status
     FROM units WHERE id = $1`,
    [unitId],
  );
  return result.rows[0];
}

export async function findUnreadNotificationCount(userId: string): Promise<number> {
  const result = await pool.query(
    `SELECT COUNT(*)::int as count FROM notifications
     WHERE user_id = $1 AND is_read = FALSE
       AND (expires_at IS NULL OR expires_at > NOW())`,
    [userId],
  );
  return Number(result.rows[0]?.count ?? 0);
}

export async function findOutstandingBalance(unitId: string): Promise<number | null> {
  // Sum of unpaid invoices for the unit via rent ledger
  const result = await pool.query(
    `SELECT COALESCE(SUM(i.total_amount - COALESCE(SUM(p.amount), 0)), 0)::numeric as balance
     FROM invoices i
     LEFT JOIN payments p ON p.invoice_id = i.id
     WHERE i.unit_id = $1 AND i.status != 'cancelled'
     GROUP BY i.unit_id`,
    [unitId],
  );
  if (result.rows.length === 0) return null;
  return Number(result.rows[0].balance);
}

export async function findInvoiceCount(unitId: string): Promise<number> {
  const result = await pool.query(
    `SELECT COUNT(*)::int as count FROM invoices WHERE unit_id = $1 AND status != 'cancelled'`,
    [unitId],
  );
  return Number(result.rows[0]?.count ?? 0);
}

// ============================================================================
// Service request types
// ============================================================================

export type MaintenanceRequestRecord = {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  reporterId: string;
  reporterRole: string;
  title: string;
  description: string;
  category: string;
  priority: string;
  status: string;
  assignedToUserId: string | null;
  assignedToOrganisationId: string | null;
  createdAt: Date;
  updatedAt: Date;
};

export type GarbageRequestRecord = {
  id: string;
  propertyId: string;
  unitId: string | null;
  garbageProviderId: string | null;
  requestType: string;
  status: string;
  scheduledAt: Date | null;
  completedAt: Date | null;
  notes: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
};

export type MovingRequestRecord = {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  tenantId: string;
  providerId: string | null;
  serviceType: string;
  pickupLocation: string;
  destinationLocation: string;
  pickupLatitude: number | null;
  pickupLongitude: number | null;
  destinationLatitude: number | null;
  destinationLongitude: number | null;
  preferredDateTime: Date | null;
  itemDescription: string | null;
  specialInstructions: string | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  status: string;
  scheduledAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  cancellationReason: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
};

export type LaundryRequestRecord = {
  id: string;
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  tenantId: string;
  providerId: string | null;
  serviceCategory: string;
  collectionPreference: string;
  preferredDateTime: Date | null;
  garmentCount: number | null;
  specialInstructions: string | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  status: string;
  scheduledAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  cancellationReason: string | null;
  createdBy: string;
  createdAt: Date;
  updatedAt: Date;
};

// ============================================================================
// Maintenance request creation (reuses property_issues table)
// ============================================================================

export async function createMaintenanceRequest(data: {
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  reporterId: string;
  title: string;
  description: string;
  category: string;
  priority: string;
  photos: string[];
  accessInstructions: string | null;
  preferredAvailability: Date | null;
}): Promise<MaintenanceRequestRecord> {
  const result = await pool.query<MaintenanceRequestRecord>(
    `INSERT INTO property_issues (
      property_id, unit_id, tenancy_id, reporter_id, reporter_role,
      title, description, category, priority, status
    ) VALUES (
      $1, $2, $3, $4, 'tenant', $5, $6, $7, $8, 'new'
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", reporter_id as "reporterId",
      reporter_role as "reporterRole", title, description, category,
      priority, status, assigned_to_user_id as "assignedToUserId",
      assigned_to_organisation_id as "assignedToOrganisationId",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.tenancyId, data.reporterId,
      data.title, data.description, data.category, data.priority,
    ],
  );
  return result.rows[0]!;
}

export async function findMaintenanceRequestById(
  requestId: string,
): Promise<MaintenanceRequestRecord | undefined> {
  const result = await pool.query<MaintenanceRequestRecord>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", reporter_id as "reporterId",
      reporter_role as "reporterRole", title, description, category,
      priority, status, assigned_to_user_id as "assignedToUserId",
      assigned_to_organisation_id as "assignedToOrganisationId",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM property_issues WHERE id = $1`,
    [requestId],
  );
  return result.rows[0];
}

// ============================================================================
// Garbage request creation (reuses garbage_collection_requests table)
// ============================================================================

export async function findGarbageProviderAssignmentForUnit(
  propertyId: string,
  unitId: string | null,
): Promise<{ garbageProviderId: string; assignmentType: string } | null> {
  const conditions: string[] = ['property_id = $1', 'status = \'active\''];
  const values: unknown[] = [propertyId];
  let paramIndex = 2;

  if (unitId) {
    conditions.push(`unit_id = $${paramIndex++}`);
    values.push(unitId);
  } else {
    conditions.push(`unit_id IS NULL`);
  }

  const result = await pool.query<{
    garbage_provider_id: string;
    assignment_type: string;
  }>(
    `SELECT garbage_provider_id, assignment_type
     FROM garbage_provider_assignments
     WHERE ${conditions.join(' AND ')}
     ORDER BY (unit_id IS NOT NULL) DESC, created_at DESC
     LIMIT 1`,
    values,
  );
  return result.rows[0]
    ? { garbageProviderId: result.rows[0].garbage_provider_id, assignmentType: result.rows[0].assignment_type }
    : null;
}

export async function createGarbageRequest(data: {
  propertyId: string;
  unitId: string | null;
  garbageProviderId: string | null;
  requestType: string;
  notes: string | null;
  createdBy: string;
}): Promise<GarbageRequestRecord> {
  const result = await pool.query<GarbageRequestRecord>(
    `INSERT INTO garbage_collection_requests (
      property_id, unit_id, garbage_provider_id, request_type,
      status, notes, created_by
    ) VALUES (
      $1, $2, $3, $4, 'pending', $5, $6
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", request_type as "requestType",
      status, scheduled_at as "scheduledAt", completed_at as "completedAt",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.garbageProviderId, data.requestType,
      data.notes, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findGarbageRequestById(
  requestId: string,
): Promise<GarbageRequestRecord | undefined> {
  const result = await pool.query<GarbageRequestRecord>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      garbage_provider_id as "garbageProviderId", request_type as "requestType",
      status, scheduled_at as "scheduledAt", completed_at as "completedAt",
      notes, created_by as "createdBy", updated_by as "updatedBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM garbage_collection_requests WHERE id = $1`,
    [requestId],
  );
  return result.rows[0];
}

// ============================================================================
// Moving request creation
// ============================================================================

export async function createMovingRequest(data: {
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  tenantId: string;
  providerId: string | null;
  serviceType: string;
  pickupLocation: string;
  destinationLocation: string;
  pickupLatitude: number | null;
  pickupLongitude: number | null;
  destinationLatitude: number | null;
  destinationLongitude: number | null;
  preferredDateTime: Date | null;
  itemDescription: string | null;
  specialInstructions: string | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  createdBy: string;
}): Promise<MovingRequestRecord> {
  const result = await pool.query<MovingRequestRecord>(
    `INSERT INTO moving_requests (
      property_id, unit_id, tenancy_id, tenant_id, provider_id,
      service_type, pickup_location, destination_location,
      pickup_latitude, pickup_longitude,
      destination_latitude, destination_longitude,
      preferred_date_time, item_description, special_instructions,
      contact_name, contact_phone, contact_email,
      status, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18,
      CASE WHEN $5::uuid IS NOT NULL THEN 'pending_confirmation'::moving_request_status ELSE 'submitted'::moving_request_status END,
      $19
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", tenant_id as "tenantId",
      provider_id as "providerId", service_type as "serviceType",
      pickup_location as "pickupLocation", destination_location as "destinationLocation",
      pickup_latitude as "pickupLatitude", pickup_longitude as "pickupLongitude",
      destination_latitude as "destinationLatitude", destination_longitude as "destinationLongitude",
      preferred_date_time as "preferredDateTime", item_description as "itemDescription",
      special_instructions as "specialInstructions", contact_name as "contactName",
      contact_phone as "contactPhone", contact_email as "contactEmail",
      status, scheduled_at as "scheduledAt", started_at as "startedAt",
      completed_at as "completedAt", cancelled_at as "cancelledAt",
      cancellation_reason as "cancellationReason", created_by as "createdBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.tenancyId, data.tenantId, data.providerId,
      data.serviceType, data.pickupLocation, data.destinationLocation,
      data.pickupLatitude, data.pickupLongitude,
      data.destinationLatitude, data.destinationLongitude,
      data.preferredDateTime, data.itemDescription, data.specialInstructions,
      data.contactName, data.contactPhone, data.contactEmail,
      data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findMovingRequestById(
  requestId: string,
): Promise<MovingRequestRecord | undefined> {
  const result = await pool.query<MovingRequestRecord>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", tenant_id as "tenantId",
      provider_id as "providerId", service_type as "serviceType",
      pickup_location as "pickupLocation", destination_location as "destinationLocation",
      pickup_latitude as "pickupLatitude", pickup_longitude as "pickupLongitude",
      destination_latitude as "destinationLatitude", destination_longitude as "destinationLongitude",
      preferred_date_time as "preferredDateTime", item_description as "itemDescription",
      special_instructions as "specialInstructions", contact_name as "contactName",
      contact_phone as "contactPhone", contact_email as "contactEmail",
      status, scheduled_at as "scheduledAt", started_at as "startedAt",
      completed_at as "completedAt", cancelled_at as "cancelledAt",
      cancellation_reason as "cancellationReason", created_by as "createdBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM moving_requests WHERE id = $1`,
    [requestId],
  );
  return result.rows[0];
}

// ============================================================================
// Laundry request creation
// ============================================================================

export async function createLaundryRequest(data: {
  propertyId: string;
  unitId: string | null;
  tenancyId: string | null;
  tenantId: string;
  providerId: string | null;
  serviceCategory: string;
  collectionPreference: string;
  preferredDateTime: Date | null;
  garmentCount: number | null;
  specialInstructions: string | null;
  contactName: string | null;
  contactPhone: string | null;
  contactEmail: string | null;
  createdBy: string;
}): Promise<LaundryRequestRecord> {
  const result = await pool.query<LaundryRequestRecord>(
    `INSERT INTO laundry_requests (
      property_id, unit_id, tenancy_id, tenant_id, provider_id,
      service_category, collection_preference, preferred_date_time,
      garment_count, special_instructions, contact_name, contact_phone,
      contact_email, status, created_by
    ) VALUES (
      $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
      CASE WHEN $5::uuid IS NOT NULL THEN 'pending_confirmation'::laundry_request_status ELSE 'submitted'::laundry_request_status END,
      $14
    )
    RETURNING
      id, property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", tenant_id as "tenantId",
      provider_id as "providerId", service_category as "serviceCategory",
      collection_preference as "collectionPreference",
      preferred_date_time as "preferredDateTime", garment_count as "garmentCount",
      special_instructions as "specialInstructions", contact_name as "contactName",
      contact_phone as "contactPhone", contact_email as "contactEmail",
      status, scheduled_at as "scheduledAt", started_at as "startedAt",
      completed_at as "completedAt", cancelled_at as "cancelledAt",
      cancellation_reason as "cancellationReason", created_by as "createdBy",
      created_at as "createdAt", updated_at as "updatedAt"`,
    [
      data.propertyId, data.unitId, data.tenancyId, data.tenantId, data.providerId,
      data.serviceCategory, data.collectionPreference, data.preferredDateTime,
      data.garmentCount, data.specialInstructions, data.contactName,
      data.contactPhone, data.contactEmail, data.createdBy,
    ],
  );
  return result.rows[0]!;
}

export async function findLaundryRequestById(
  requestId: string,
): Promise<LaundryRequestRecord | undefined> {
  const result = await pool.query<LaundryRequestRecord>(
    `SELECT
      id, property_id as "propertyId", unit_id as "unitId",
      tenancy_id as "tenancyId", tenant_id as "tenantId",
      provider_id as "providerId", service_category as "serviceCategory",
      collection_preference as "collectionPreference",
      preferred_date_time as "preferredDateTime", garment_count as "garmentCount",
      special_instructions as "specialInstructions", contact_name as "contactName",
      contact_phone as "contactPhone", contact_email as "contactEmail",
      status, scheduled_at as "scheduledAt", started_at as "startedAt",
      completed_at as "completedAt", cancelled_at as "cancelledAt",
      cancellation_reason as "cancellationReason", created_by as "createdBy",
      created_at as "createdAt", updated_at as "updatedAt"
    FROM laundry_requests WHERE id = $1`,
    [requestId],
  );
  return result.rows[0];
}

// ============================================================================
// Tenant request listing (scoped to the authenticated tenant)
// ============================================================================

export type RequestListQuery = {
  status?: string;
  limit: number;
  offset: number;
};

export type PaginatedRows<T> = {
  rows: T[];
  total: number;
};

export async function listMovingRequestsByTenant(
  tenantId: string,
  query: RequestListQuery,
): Promise<PaginatedRows<MovingRequestRecord & { providerName: string | null }>> {
  const conditions: string[] = ['mr.tenant_id = $1'];
  const values: unknown[] = [tenantId];
  let i = 2;
  if (query.status) {
    conditions.push(`mr.status::text = $${i++}`);
    values.push(query.status);
  }
  const where = conditions.join(' AND ');

  const totalResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::int as count FROM moving_requests mr WHERE ${where}`,
    values,
  );
  const total = Number(totalResult.rows[0]?.count ?? 0);

  const result = await pool.query<MovingRequestRecord & { providerName: string | null }>(
    `SELECT mr.id, mr.property_id as "propertyId", mr.unit_id as "unitId",
            mr.tenancy_id as "tenancyId", mr.tenant_id as "tenantId",
            mr.provider_id as "providerId", mr.service_type as "serviceType",
            mr.pickup_location as "pickupLocation", mr.destination_location as "destinationLocation",
            mr.pickup_latitude as "pickupLatitude", mr.pickup_longitude as "pickupLongitude",
            mr.destination_latitude as "destinationLatitude", mr.destination_longitude as "destinationLongitude",
            mr.preferred_date_time as "preferredDateTime", mr.item_description as "itemDescription",
            mr.special_instructions as "specialInstructions", mr.contact_name as "contactName",
            mr.contact_phone as "contactPhone", mr.contact_email as "contactEmail",
            mr.status, mr.scheduled_at as "scheduledAt", mr.started_at as "startedAt",
            mr.completed_at as "completedAt", mr.cancelled_at as "cancelledAt",
            mr.cancellation_reason as "cancellationReason", mr.created_by as "createdBy",
            mr.created_at as "createdAt", mr.updated_at as "updatedAt",
            sp.business_name as "providerName"
     FROM moving_requests mr
     LEFT JOIN specialized_profiles sp ON sp.id = mr.provider_id
     WHERE ${where}
     ORDER BY mr.created_at DESC
     LIMIT $${i++} OFFSET $${i++}`,
    [...values, query.limit, query.offset],
  );
  return { rows: result.rows, total };
}

export async function listLaundryRequestsByTenant(
  tenantId: string,
  query: RequestListQuery,
): Promise<PaginatedRows<LaundryRequestRecord & { providerName: string | null }>> {
  const conditions: string[] = ['lr.tenant_id = $1'];
  const values: unknown[] = [tenantId];
  let i = 2;
  if (query.status) {
    conditions.push(`lr.status::text = $${i++}`);
    values.push(query.status);
  }
  const where = conditions.join(' AND ');

  const totalResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::int as count FROM laundry_requests lr WHERE ${where}`,
    values,
  );
  const total = Number(totalResult.rows[0]?.count ?? 0);

  const result = await pool.query<LaundryRequestRecord & { providerName: string | null }>(
    `SELECT lr.id, lr.property_id as "propertyId", lr.unit_id as "unitId",
            lr.tenancy_id as "tenancyId", lr.tenant_id as "tenantId",
            lr.provider_id as "providerId", lr.service_category as "serviceCategory",
            lr.collection_preference as "collectionPreference",
            lr.preferred_date_time as "preferredDateTime", lr.garment_count as "garmentCount",
            lr.special_instructions as "specialInstructions", lr.contact_name as "contactName",
            lr.contact_phone as "contactPhone", lr.contact_email as "contactEmail",
            lr.status, lr.scheduled_at as "scheduledAt", lr.started_at as "startedAt",
            lr.completed_at as "completedAt", lr.cancelled_at as "cancelledAt",
            lr.cancellation_reason as "cancellationReason", lr.created_by as "createdBy",
            lr.created_at as "createdAt", lr.updated_at as "updatedAt",
            sp.business_name as "providerName"
     FROM laundry_requests lr
     LEFT JOIN specialized_profiles sp ON sp.id = lr.provider_id
     WHERE ${where}
     ORDER BY lr.created_at DESC
     LIMIT $${i++} OFFSET $${i++}`,
    [...values, query.limit, query.offset],
  );
  return { rows: result.rows, total };
}

export async function listGarbageRequestsByUnit(
  unitId: string,
  query: RequestListQuery,
): Promise<PaginatedRows<GarbageRequestRecord & { providerName: string | null }>> {
  const conditions: string[] = ['gcr.unit_id = $1'];
  const values: unknown[] = [unitId];
  let i = 2;
  if (query.status) {
    conditions.push(`gcr.status::text = $${i++}`);
    values.push(query.status);
  }
  const where = conditions.join(' AND ');

  const totalResult = await pool.query<{ count: string }>(
    `SELECT COUNT(*)::int as count FROM garbage_collection_requests gcr WHERE ${where}`,
    values,
  );
  const total = Number(totalResult.rows[0]?.count ?? 0);

  const result = await pool.query<GarbageRequestRecord & { providerName: string | null }>(
    `SELECT gcr.id, gcr.unit_id as "unitId", gcr.property_id as "propertyId",
            gcr.request_type as "requestType", gcr.status,
            gcr.notes, gcr.scheduled_at as "scheduledAt",
            gcr.completed_at as "completedAt", gcr.created_at as "createdAt",
            gcr.updated_at as "updatedAt",
            gcr.garbage_provider_id as "garbageProviderId",
            gp.name as "providerName"
     FROM garbage_collection_requests gcr
     LEFT JOIN garbage_providers gp ON gp.id = gcr.garbage_provider_id
     WHERE ${where}
     ORDER BY gcr.created_at DESC
     LIMIT $${i++} OFFSET $${i++}`,
    [...values, query.limit, query.offset],
  );
  return { rows: result.rows, total };
}

// ============================================================================
// Cancellation (tenant-owned requests only)
// ============================================================================

export async function cancelMaintenanceRequest(
  requestId: string,
  cancelledBy: string,
  reason: string | null,
): Promise<MaintenanceRequestRecord | undefined> {
  const result = await pool.query<MaintenanceRequestRecord>(
    `UPDATE property_issues
     SET status = 'cancelled', updated_at = NOW()
     WHERE id = $1 AND reporter_id = $2 AND status NOT IN ('resolved', 'closed', 'cancelled')
     RETURNING
       id, property_id as "propertyId", unit_id as "unitId",
       tenancy_id as "tenancyId", reporter_id as "reporterId",
       reporter_role as "reporterRole", title, description, category,
       priority, status, assigned_to_user_id as "assignedToUserId",
       assigned_to_organisation_id as "assignedToOrganisationId",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [requestId, cancelledBy],
  );
  return result.rows[0];
}

export async function cancelGarbageRequest(
  requestId: string,
  cancelledBy: string,
): Promise<GarbageRequestRecord | undefined> {
  const result = await pool.query<GarbageRequestRecord>(
    `UPDATE garbage_collection_requests
     SET status = 'cancelled', updated_by = $2, updated_at = NOW()
     WHERE id = $1 AND created_by = $2 AND status NOT IN ('completed', 'cancelled')
     RETURNING
       id, property_id as "propertyId", unit_id as "unitId",
       garbage_provider_id as "garbageProviderId", request_type as "requestType",
       status, scheduled_at as "scheduledAt", completed_at as "completedAt",
       notes, created_by as "createdBy", updated_by as "updatedBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [requestId, cancelledBy],
  );
  return result.rows[0];
}

export async function cancelMovingRequest(
  requestId: string,
  tenantId: string,
  cancelledBy: string,
  reason: string | null,
): Promise<MovingRequestRecord | undefined> {
  const result = await pool.query<MovingRequestRecord>(
    `UPDATE moving_requests
     SET status = 'cancelled', cancelled_at = NOW(),
         cancellation_reason = $3, cancelled_by = $4,
         updated_by = $4, updated_at = NOW()
     WHERE id = $1 AND tenant_id = $2
     AND status NOT IN ('completed', 'cancelled')
     RETURNING
       id, property_id as "propertyId", unit_id as "unitId",
       tenancy_id as "tenancyId", tenant_id as "tenantId",
       provider_id as "providerId", service_type as "serviceType",
       pickup_location as "pickupLocation", destination_location as "destinationLocation",
       pickup_latitude as "pickupLatitude", pickup_longitude as "pickupLongitude",
       destination_latitude as "destinationLatitude", destination_longitude as "destinationLongitude",
       preferred_date_time as "preferredDateTime", item_description as "itemDescription",
       special_instructions as "specialInstructions", contact_name as "contactName",
       contact_phone as "contactPhone", contact_email as "contactEmail",
       status, scheduled_at as "scheduledAt", started_at as "startedAt",
       completed_at as "completedAt", cancelled_at as "cancelledAt",
       cancellation_reason as "cancellationReason", created_by as "createdBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [requestId, tenantId, reason, cancelledBy],
  );
  return result.rows[0];
}

export async function cancelLaundryRequest(
  requestId: string,
  tenantId: string,
  cancelledBy: string,
  reason: string | null,
): Promise<LaundryRequestRecord | undefined> {
  const result = await pool.query<LaundryRequestRecord>(
    `UPDATE laundry_requests
     SET status = 'cancelled', cancelled_at = NOW(),
         cancellation_reason = $3, cancelled_by = $4,
         updated_by = $4, updated_at = NOW()
     WHERE id = $1 AND tenant_id = $2
     AND status NOT IN ('completed', 'cancelled')
     RETURNING
       id, property_id as "propertyId", unit_id as "unitId",
       tenancy_id as "tenancyId", tenant_id as "tenantId",
       provider_id as "providerId", service_category as "serviceCategory",
       collection_preference as "collectionPreference",
       preferred_date_time as "preferredDateTime", garment_count as "garmentCount",
       special_instructions as "specialInstructions", contact_name as "contactName",
       contact_phone as "contactPhone", contact_email as "contactEmail",
       status, scheduled_at as "scheduledAt", started_at as "startedAt",
       completed_at as "completedAt", cancelled_at as "cancelledAt",
       cancellation_reason as "cancellationReason", created_by as "createdBy",
       created_at as "createdAt", updated_at as "updatedAt"`,
    [requestId, tenantId, reason, cancelledBy],
  );
  return result.rows[0];
}
