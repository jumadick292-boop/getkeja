-- Migration: 131_create_recurring_billing.sql
-- Description: Recurring rent billing schedules, versioned rent terms, billing
--              run history, and additive invoice columns for Task 14.1.
--              Additive only: reuses the existing invoices/invoice_items tables
--              (migration 078). No existing financial records are modified or
--              deleted. All money is DECIMAL(12,2) with explicit currency.

-- ---------------------------------------------------------------------------
-- Enums (idempotent creation)
-- ---------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE billing_frequency AS ENUM ('monthly', 'quarterly', 'annual');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE billing_schedule_status AS ENUM (
        'pending', 'active', 'suspended', 'cancelled'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE billing_run_status AS ENUM ('succeeded', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ---------------------------------------------------------------------------
-- Rental billing schedules
-- A schedule drives recurring invoice generation for one active tenancy.
-- billing_day is the day-of-month the period starts / rent is billed (1..28).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rental_billing_schedules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE RESTRICT,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    lease_agreement_id UUID REFERENCES rental_agreements(id) ON DELETE SET NULL,
    rent_amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    billing_frequency billing_frequency NOT NULL DEFAULT 'monthly',
    billing_day SMALLINT NOT NULL DEFAULT 1,
    first_billing_date DATE NOT NULL,
    next_billing_date DATE NOT NULL,
    due_day_of_month SMALLINT,
    grace_period_days INTEGER NOT NULL DEFAULT 0,
    status billing_schedule_status NOT NULL DEFAULT 'pending',
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    suspended_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_billing_schedule_rent CHECK (rent_amount > 0),
    CONSTRAINT chk_billing_schedule_day CHECK (billing_day BETWEEN 1 AND 28),
    CONSTRAINT chk_billing_schedule_due_day CHECK (
        due_day_of_month IS NULL OR (due_day_of_month BETWEEN 1 AND 28)
    ),
    CONSTRAINT chk_billing_schedule_grace CHECK (grace_period_days >= 0),
    CONSTRAINT chk_billing_schedule_dates CHECK (next_billing_date >= first_billing_date)
);

CREATE INDEX IF NOT EXISTS idx_billing_schedules_tenancy_id ON rental_billing_schedules (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_billing_schedules_property_id ON rental_billing_schedules (property_id);
CREATE INDEX IF NOT EXISTS idx_billing_schedules_unit_id ON rental_billing_schedules (unit_id);
CREATE INDEX IF NOT EXISTS idx_billing_schedules_tenant_id ON rental_billing_schedules (tenant_id);
CREATE INDEX IF NOT EXISTS idx_billing_schedules_status ON rental_billing_schedules (status);
CREATE INDEX IF NOT EXISTS idx_billing_schedules_next ON rental_billing_schedules (next_billing_date) WHERE status = 'active';

-- At most one active schedule per tenancy at any time.
CREATE UNIQUE INDEX IF NOT EXISTS uq_billing_schedules_active_tenancy
    ON rental_billing_schedules (tenancy_id) WHERE status = 'active';

-- ---------------------------------------------------------------------------
-- Versioned rent terms. A rent change inserts a new version; history is never
-- overwritten. A billing run selects the latest version effective on or before
-- the billing period start.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rent_term_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    billing_schedule_id UUID REFERENCES rental_billing_schedules(id) ON DELETE SET NULL,
    rent_amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    billing_frequency billing_frequency NOT NULL DEFAULT 'monthly',
    due_day_of_month SMALLINT,
    grace_period_days INTEGER NOT NULL DEFAULT 0,
    effective_date DATE NOT NULL,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    superseded_at TIMESTAMPTZ,
    CONSTRAINT chk_rent_term_amount CHECK (rent_amount > 0),
    CONSTRAINT chk_rent_term_grace CHECK (grace_period_days >= 0)
);

CREATE INDEX IF NOT EXISTS idx_rent_terms_tenancy ON rent_term_versions (tenancy_id, effective_date DESC);
CREATE INDEX IF NOT EXISTS idx_rent_terms_schedule ON rent_term_versions (billing_schedule_id);

-- ---------------------------------------------------------------------------
-- Billing run history: one row per (schedule, billing period) attempt outcome.
-- Provides observability and a safe retry record alongside the DB-level
-- invoice uniqueness constraint.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS billing_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    billing_schedule_id UUID NOT NULL REFERENCES rental_billing_schedules(id) ON DELETE CASCADE,
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    status billing_run_status NOT NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    attempt_count INTEGER NOT NULL DEFAULT 1,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_billing_run_period CHECK (billing_period_end >= billing_period_start)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_billing_runs_schedule_period
    ON billing_runs (billing_schedule_id, billing_period_start);
CREATE INDEX IF NOT EXISTS idx_billing_runs_status ON billing_runs (status);

-- ---------------------------------------------------------------------------
-- Additive invoice columns (reuse existing invoices table from 078).
-- issued_at backs the tenant "issuedAt" field; source distinguishes manual vs
-- recurring invoices; billing_schedule_id + period unique index guarantees
-- idempotency at the database level.
-- ---------------------------------------------------------------------------
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS billing_schedule_id UUID REFERENCES rental_billing_schedules(id) ON DELETE SET NULL;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS source VARCHAR(20) NOT NULL DEFAULT 'manual';
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS issued_at TIMESTAMPTZ;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS description TEXT;

CREATE INDEX IF NOT EXISTS idx_invoices_billing_schedule_id ON invoices (billing_schedule_id);
CREATE INDEX IF NOT EXISTS idx_invoices_source ON invoices (source);

-- DB-enforced idempotency: a schedule may produce at most one invoice per
-- billing period start. Partial index so manual invoices (NULL schedule) are
-- unaffected.
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoices_schedule_period
    ON invoices (billing_schedule_id, billing_period_start)
    WHERE billing_schedule_id IS NOT NULL;

-- Keep updated_at fresh for schedules and billing runs.
CREATE OR REPLACE FUNCTION update_billing_schedules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_billing_schedules_updated_at ON rental_billing_schedules;
CREATE TRIGGER trigger_update_billing_schedules_updated_at
    BEFORE UPDATE ON rental_billing_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_billing_schedules_updated_at();

CREATE OR REPLACE FUNCTION update_billing_runs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_billing_runs_updated_at ON billing_runs;
CREATE TRIGGER trigger_update_billing_runs_updated_at
    BEFORE UPDATE ON billing_runs
    FOR EACH ROW
    EXECUTE FUNCTION update_billing_runs_updated_at();