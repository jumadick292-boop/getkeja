// Rental onboarding handoff.
//
// Idempotent, concurrency-safe transition from an APPROVED application to a
// real tenancy + tenant record. This is the ONLY place an application creates a
// tenant — and only when the application is already approved. Submitting an
// application, an enquiry, a site visit, or accepting a proposal never creates
// a tenant.
//
// Guarantees:
//  - Never creates a tenant/tenancy unless application.status = 'approved'.
//  - Idempotent: if the application already carries a tenancy_id, the existing
//    tenancy is returned (safe to retry).
//  - Race-safe: serialises on the application row, then the unit row, so two
//    concurrent approvals/onboardings for the same unit cannot both succeed.

import { randomUUID } from 'node:crypto';
import type { PoolClient } from 'pg';
import { ConflictError, HttpError, NotFoundError } from '../../shared/errors.js';
import { transaction } from '../../db/tx.js';
import { findApplication, hasCompetingApproved } from './rental-application.repository.js';

export interface OnboardingResult {
  alreadyOnboarded: boolean;
  tenancyId: string;
  tenantId: string;
  unitId: string;
}

async function createTenancyRow(
  client: PoolClient,
  data: {
    propertyId: string;
    unitId: string;
    startDate: Date;
    endDate: Date | null;
    rentAmount: number;
    depositAmount: number;
    termsAcceptedAt: Date;
    createdBy: string;
  },
): Promise<string> {
  const result = await client.query<{ id: string }>(
    `INSERT INTO tenancies
       (id, property_id, unit_id, tenancy_type, status, start_date, end_date,
        notice_period_days, rent_amount, deposit_amount, deposit_paid, rent_due_day, terms_accepted_at, created_by)
     VALUES ($1, $2, $3, 'residential', 'active', $4, $5, 30, $6, $7, FALSE, 1, $8, $9)
     RETURNING id`,
    [
      randomUUID(),
      data.propertyId,
      data.unitId,
      data.startDate,
      data.endDate,
      data.rentAmount,
      data.depositAmount,
      data.termsAcceptedAt,
      data.createdBy,
    ],
  );
  return result.rows[0]!.id;
}

async function createTenantRow(
  client: PoolClient,
  data: {
    userId: string | null;
    propertyId: string;
    unitId: string;
    tenancyId: string;
    fullName: string;
    email: string | null;
    phone: string;
    employerName: string | null;
    employerContact: string | null;
    monthlyIncome: number | null;
    previousLandlordName: string | null;
    previousLandlordContact: string | null;
    moveInDate: Date | null;
    createdBy: string;
  },
): Promise<string> {
  const result = await client.query<{ id: string }>(
    `INSERT INTO tenants
       (user_id, property_id, unit_id, tenancy_id, full_name, email, phone,
        employer_name, employer_contact, monthly_income,
        previous_landlord_name, previous_landlord_contact, move_in_date, status, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'active', $14)
     RETURNING id`,
    [
      data.userId,
      data.propertyId,
      data.unitId,
      data.tenancyId,
      data.fullName,
      data.email,
      data.phone,
      data.employerName,
      data.employerContact,
      data.monthlyIncome,
      data.previousLandlordName,
      data.previousLandlordContact,
      data.moveInDate,
      data.createdBy,
    ],
  );
  return result.rows[0]!.id;
}

/**
 * Create (or return the existing) tenancy + tenant for an approved application.
 * Throws if the application is not approved, or if the unit is unavailable due
 * to a competing approval / existing active tenancy.
 */
export async function initiateOnboarding(
  applicationId: string,
  actorId: string,
): Promise<OnboardingResult> {
  return transaction(async (client) => {
    const application = await findApplication(client, applicationId, true);
    if (!application) throw new NotFoundError('Application not found');

    if (application.status !== 'approved') {
      throw new ConflictError('Only approved applications can be onboarded');
    }

    // Idempotent: onboarding already completed.
    if (application.tenancyId) {
      const existingTenant = await client.query<{ id: string }>(
        `SELECT id FROM tenants WHERE tenancy_id = $1 LIMIT 1`,
        [application.tenancyId],
      );
      return {
        alreadyOnboarded: true,
        tenancyId: application.tenancyId,
        tenantId: existingTenant.rows[0]?.id ?? '',
        unitId: application.unitId ?? '',
      };
    }

    if (!application.unitId) {
      throw new HttpError('A unit is required to onboard an application into a tenancy', 400);
    }

    // Precondition: an accepted/confirmed proposal must be linked to this
    // application. The seeker's acceptance of the proposal constitutes agreement
    // to the rental terms (rent, deposit, dates), which is the terms-acceptance
    // gate before a tenancy can be created.
    const acceptedProposal = await client.query<{ id: string; accepted_at: Date | null }>(
      `SELECT id, accepted_at FROM rental_proposals
       WHERE rental_application_id = $1
         AND status IN ('accepted', 'confirmed')
       ORDER BY accepted_at DESC NULLS LAST, created_at DESC
       LIMIT 1`,
      [applicationId],
    );
    if (acceptedProposal.rows.length === 0) {
      throw new ConflictError(
        'Cannot onboard: no accepted or confirmed proposal linked to this application',
      );
    }
    const termsAcceptedAt = acceptedProposal.rows[0]!.accepted_at ?? new Date();

    // Lock the unit so competing onboardings/approvals for the same unit serialise.
    const unit = await client.query<{ status: string }>(
      `SELECT status FROM units WHERE id = $1 FOR UPDATE`,
      [application.unitId],
    );
    if (!unit.rows[0]) throw new NotFoundError('Unit not found');

    // Guard against a competing approved application for the same unit.
    if (await hasCompetingApproved(client, application.unitId, application.id)) {
      throw new ConflictError('Another application is already approved for this unit');
    }

    // Guard against onboarding into a unit that already has an active tenancy.
    const activeTenancy = await client.query<{ id: string }>(
      `SELECT id FROM tenancies WHERE unit_id = $1 AND status = 'active' LIMIT 1`,
      [application.unitId],
    );
    if (activeTenancy.rows[0]) {
      throw new ConflictError('This unit already has an active tenancy');
    }

    const rentAmount = Number(application.approvedRentAmount ?? application.proposedRentAmount ?? 0);
    const depositAmount = Number(application.approvedDepositAmount ?? 0);
    const startDate =
      application.approvedStartDate ?? application.preferredStartDate ?? new Date();
    const endDate = application.approvedEndDate ?? application.preferredEndDate ?? null;

    const tenancyId = await createTenancyRow(client, {
      propertyId: application.propertyId,
      unitId: application.unitId,
      startDate: new Date(startDate),
      endDate: endDate ? new Date(endDate) : null,
      rentAmount,
      depositAmount,
      termsAcceptedAt,
      createdBy: actorId,
    });

    const tenantId = await createTenantRow(client, {
      userId: application.userId,
      propertyId: application.propertyId,
      unitId: application.unitId,
      tenancyId,
      fullName: application.applicantName,
      email: application.applicantEmail || null,
      phone: application.applicantPhone || '',
      employerName: application.employerName,
      employerContact: application.employerContact,
      monthlyIncome: application.monthlyIncome,
      previousLandlordName: application.previousLandlordName,
      previousLandlordContact: application.previousLandlordContact,
      moveInDate: new Date(startDate),
      createdBy: actorId,
    });

    // The unit becomes explicitly occupied only at onboarding (not at approval,
    // not at application submission).
    if (unit.rows[0]!.status !== 'occupied') {
      await client.query(`UPDATE units SET status = 'occupied' WHERE id = $1`, [application.unitId]);
    }

    // Link the application to the tenancy (does not change status → no history row).
    await client.query(
      `UPDATE rental_applications SET tenancy_id = $1, updated_by = $2 WHERE id = $3`,
      [tenancyId, actorId, applicationId],
    );

    return { alreadyOnboarded: false, tenancyId, tenantId, unitId: application.unitId };
  });
}