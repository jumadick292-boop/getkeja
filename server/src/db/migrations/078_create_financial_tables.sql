-- Migration: 078_create_financial_tables
-- Description: Create invoices, payments, ledger, deposits, and expense tables

CREATE TYPE invoice_status AS ENUM ('draft', 'issued', 'sent', 'paid', 'partially_paid', 'overdue', 'cancelled', 'refunded', 'void');
CREATE TYPE payment_transaction_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'reversed', 'refunded');
CREATE TYPE payment_provider AS ENUM ('mpesa', 'bank_transfer', 'cash', 'cheque', 'manual', 'other');
CREATE TYPE charge_type AS ENUM ('rent', 'deposit', 'service_charge', 'garbage_charge', 'utility_charge', 'maintenance_charge', 'late_fee', 'other');
CREATE TYPE expense_category_type AS ENUM ('maintenance', 'repair', 'garbage_service', 'utilities', 'insurance', 'property_tax', 'management_fee', 'marketing', 'legal', 'other');
CREATE TYPE deposit_status AS ENUM ('expected', 'partially_received', 'received', 'refunded', 'partially_refunded', 'forfeited', 'transferred');

CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    colour VARCHAR(20),
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (name)
);

CREATE INDEX IF NOT EXISTS idx_expense_categories_is_system ON expense_categories (is_system);

CREATE TABLE IF NOT EXISTS property_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    expense_category_id UUID REFERENCES expense_categories(id) ON DELETE SET NULL,
    category expense_category_type NOT NULL,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    expense_date DATE NOT NULL,
    receipt_document_url VARCHAR(500),
    vendor_name VARCHAR(255),
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_expense_amount CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_property_expenses_property_id ON property_expenses (property_id);
CREATE INDEX IF NOT EXISTS idx_property_expenses_unit_id ON property_expenses (unit_id);
CREATE INDEX IF NOT EXISTS idx_property_expenses_category ON property_expenses (category);
CREATE INDEX IF NOT EXISTS idx_property_expenses_expense_date ON property_expenses (expense_date);
CREATE INDEX IF NOT EXISTS idx_property_expenses_created_by ON property_expenses (created_by);

CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(100) NOT NULL,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    status invoice_status NOT NULL DEFAULT 'draft',
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    due_date DATE NOT NULL,
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0,
    amount_outstanding DECIMAL(12, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_invoice_dates CHECK (billing_period_end >= billing_period_start),
    CONSTRAINT chk_invoice_due_date CHECK (due_date >= billing_period_start),
    CONSTRAINT chk_invoice_total CHECK (total_amount >= 0),
    CONSTRAINT chk_invoice_paid CHECK (amount_paid >= 0),
    UNIQUE (invoice_number)
);

CREATE INDEX IF NOT EXISTS idx_invoices_property_id ON invoices (property_id);
CREATE INDEX IF NOT EXISTS idx_invoices_unit_id ON invoices (unit_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenant_id ON invoices (tenant_id);
CREATE INDEX IF NOT EXISTS idx_invoices_tenancy_id ON invoices (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON invoices (status);
CREATE INDEX IF NOT EXISTS idx_invoices_due_date ON invoices (due_date);
CREATE INDEX IF NOT EXISTS idx_invoices_invoice_number ON invoices (invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices (created_at DESC);

CREATE TABLE IF NOT EXISTS invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    charge_type charge_type NOT NULL,
    description VARCHAR(255) NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    billing_period_start DATE,
    billing_period_end DATE,
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(12, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_invoice_item_amount CHECK (amount > 0),
    CONSTRAINT chk_invoice_item_quantity CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON invoice_items (invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_charge_type ON invoice_items (charge_type);

CREATE TABLE IF NOT EXISTS payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(100) NOT NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    provider payment_provider NOT NULL,
    provider_transaction_id VARCHAR(255),
    status payment_transaction_status NOT NULL DEFAULT 'pending',
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    callback_payload JSONB,
    callback_received_at TIMESTAMPTZ,
    processed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    failure_reason TEXT,
    notes TEXT,
    idempotency_key VARCHAR(255),
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    UNIQUE (idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_payment_transactions_transaction_ref ON payment_transactions (transaction_reference);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_invoice_id ON payment_transactions (invoice_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_tenant_id ON payment_transactions (tenant_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_property_id ON payment_transactions (property_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_provider ON payment_transactions (provider);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON payment_transactions (status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_payment_date ON payment_transactions (payment_date);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_idempotency_key ON payment_transactions (idempotency_key);

CREATE TABLE IF NOT EXISTS payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    amount_allocated DECIMAL(12, 2) NOT NULL,
    allocated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    allocated_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_allocation_amount CHECK (amount_allocated > 0)
);

CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment_id ON payment_allocations (payment_transaction_id);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_invoice_id ON payment_allocations (invoice_id);

CREATE TABLE IF NOT EXISTS rent_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    entry_type VARCHAR(30) NOT NULL, -- 'charge', 'payment', 'adjustment', 'credit', 'refund'
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    billing_period_start DATE,
    billing_period_end DATE,
    due_date DATE,
    payment_date TIMESTAMPTZ,
    reference VARCHAR(255),
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rent_ledger_entries_tenancy_id ON rent_ledger_entries (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_rent_ledger_entries_tenant_id ON rent_ledger_entries (tenant_id);
CREATE INDEX IF NOT EXISTS idx_rent_ledger_entries_property_id ON rent_ledger_entries (property_id);
CREATE INDEX IF NOT EXISTS idx_rent_ledger_entries_entry_type ON rent_ledger_entries (entry_type);
CREATE INDEX IF NOT EXISTS idx_rent_ledger_entries_created_at ON rent_ledger_entries (created_at DESC);

CREATE TABLE IF NOT EXISTS tenant_deposits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    expected_amount DECIMAL(12, 2) NOT NULL,
    received_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    outstanding_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    status deposit_status NOT NULL DEFAULT 'expected',
    deposit_scheme_reference VARCHAR(255),
    held_by VARCHAR(50), -- 'landlord', 'agency', 'scheme'
    refund_due_date DATE,
    refund_amount DECIMAL(12, 2),
    refunded_at TIMESTAMPTZ,
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_deposit_expected CHECK (expected_amount > 0),
    CONSTRAINT chk_deposit_received CHECK (received_amount >= 0),
    CONSTRAINT chk_deposit_outstanding CHECK (outstanding_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_tenant_deposits_tenant_id ON tenant_deposits (tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_deposits_tenancy_id ON tenant_deposits (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_tenant_deposits_property_id ON tenant_deposits (property_id);
CREATE INDEX IF NOT EXISTS idx_tenant_deposits_status ON tenant_deposits (status);

CREATE TABLE IF NOT EXISTS deposit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deposit_id UUID NOT NULL REFERENCES tenant_deposits(id) ON DELETE CASCADE,
    transaction_type VARCHAR(30) NOT NULL, -- 'received', 'refunded', 'adjusted', 'forfeited', 'transferred'
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reference VARCHAR(255),
    notes TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_deposit_transaction_amount CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS idx_deposit_transactions_deposit_id ON deposit_transactions (deposit_id);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_invoices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_invoices_updated_at ON invoices;
CREATE TRIGGER trigger_update_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW
    EXECUTE FUNCTION update_invoices_updated_at();

CREATE OR REPLACE FUNCTION update_property_expenses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_property_expenses_updated_at ON property_expenses;
CREATE TRIGGER trigger_update_property_expenses_updated_at
    BEFORE UPDATE ON property_expenses
    FOR EACH ROW
    EXECUTE FUNCTION update_property_expenses_updated_at();

CREATE OR REPLACE FUNCTION update_payment_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_payment_transactions_updated_at ON payment_transactions;
CREATE TRIGGER trigger_update_payment_transactions_updated_at
    BEFORE UPDATE ON payment_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_payment_transactions_updated_at();

CREATE OR REPLACE FUNCTION update_tenant_deposits_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_tenant_deposits_updated_at ON tenant_deposits;
CREATE TRIGGER trigger_update_tenant_deposits_updated_at
    BEFORE UPDATE ON tenant_deposits
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_deposits_updated_at();

-- Seed default expense categories
INSERT INTO expense_categories (id, name, description, colour, is_system) VALUES
    ('11111111-1111-1111-1111-111111111101', 'Maintenance', 'General maintenance and repairs', '#3B82F6', TRUE),
    ('11111111-1111-1111-1111-111111111102', 'Garbage Service', 'Garbage collection and waste management', '#EF4444', TRUE),
    ('11111111-1111-1111-1111-111111111103', 'Utilities', 'Water, electricity, and other utilities', '#10B981', TRUE),
    ('11111111-1111-1111-1111-111111111104', 'Management Fee', 'Property management fees', '#8B5CF6', TRUE),
    ('11111111-1111-1111-1111-111111111105', 'Other', 'Miscellaneous expenses', '#6B7280', TRUE)
ON CONFLICT (name) DO NOTHING;
