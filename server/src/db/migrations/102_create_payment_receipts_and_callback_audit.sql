-- Migration: 102_create_payment_receipts_and_callback_audit
-- Description: Add receipts, callback audit, and unique provider transaction references

-- Receipts issued only for confirmed successful payments.
CREATE TABLE IF NOT EXISTS receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number VARCHAR(100) NOT NULL UNIQUE,
    payment_transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
    invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    tenancy_id UUID REFERENCES tenancies(id) ON DELETE SET NULL,
    property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    unit_id UUID REFERENCES units(id) ON DELETE SET NULL,
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    payment_method VARCHAR(50) NOT NULL,
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transaction_reference VARCHAR(255) NOT NULL, -- verified provider transaction reference
    outstanding_balance_after DECIMAL(12, 2) NOT NULL DEFAULT 0,
    storage_key VARCHAR(500), -- private document storage key for the receipt PDF
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_receipt_amount CHECK (amount > 0),
    CONSTRAINT chk_receipt_outstanding CHECK (outstanding_balance_after >= 0)
);

CREATE INDEX IF NOT EXISTS idx_receipts_receipt_number ON receipts (receipt_number);
CREATE INDEX IF NOT EXISTS idx_receipts_payment_transaction_id ON receipts (payment_transaction_id);
CREATE INDEX IF NOT EXISTS idx_receipts_invoice_id ON receipts (invoice_id);
CREATE INDEX IF NOT EXISTS idx_receipts_tenant_id ON receipts (tenant_id);
CREATE INDEX IF NOT EXISTS idx_receipts_tenancy_id ON receipts (tenancy_id);
CREATE INDEX IF NOT EXISTS idx_receipts_created_at ON receipts (created_at DESC);

-- Audit log of every incoming payment-provider callback (untrusted until verified).
CREATE TABLE IF NOT EXISTS payment_callback_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(50) NOT NULL,
    provider_transaction_id VARCHAR(255),
    event_type VARCHAR(100) NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload JSONB NOT NULL,
    processed BOOLEAN NOT NULL DEFAULT FALSE,
    processed_at TIMESTAMPTZ,
    processing_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_callback_audit_provider_tx ON payment_callback_audit (provider, provider_transaction_id);
CREATE INDEX IF NOT EXISTS idx_callback_audit_received_at ON payment_callback_audit (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_callback_audit_processed ON payment_callback_audit (processed);

-- Prevent duplicate recording of the same provider transaction (partial
-- unique index: multiple NULL provider_transaction_id values are allowed).
CREATE UNIQUE INDEX IF NOT EXISTS uk_payment_transactions_provider_tx
  ON payment_transactions (provider_transaction_id)
  WHERE provider_transaction_id IS NOT NULL;

-- Trigger to keep updated_at current on receipts is unnecessary (receipts are
-- immutable once issued); created_at is the authoritative timestamp.
