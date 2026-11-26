-- Migration: 103_add_multi_provider_payment_support
-- Description: Add Pesapal, Paybill, Till provider types; unmatched payments and reversals tables

-- Add new payment provider types to the enum.
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'pesapal';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'mpesa_paybill';
ALTER TYPE payment_provider ADD VALUE IF NOT EXISTS 'mpesa_till';

-- Unmatched payments queue: provider-confirmed payments that cannot be
-- matched to an invoice/tenancy (e.g. Paybill/Till payments without a valid
-- reference). Admin reconciliation resolves these.
CREATE TABLE IF NOT EXISTS unmatched_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider payment_provider NOT NULL,
    provider_transaction_id VARCHAR(255) NOT NULL,
    merchant_reference VARCHAR(255),
    phone_number VARCHAR(50),
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    transaction_date TIMESTAMPTZ,
    callback_payload JSONB,
    matched_payment_transaction_id UUID REFERENCES payment_transactions(id) ON DELETE SET NULL,
    matched BOOLEAN NOT NULL DEFAULT FALSE,
    match_notes TEXT,
    matched_by UUID REFERENCES users(id) ON DELETE SET NULL,
    matched_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_unmatched_amount CHECK (amount > 0),
    UNIQUE (provider, provider_transaction_id)
);

CREATE INDEX IF NOT EXISTS idx_unmatched_payments_matched ON unmatched_payments (matched);
CREATE INDEX IF NOT EXISTS idx_unmatched_payments_provider_tx ON unmatched_payments (provider, provider_transaction_id);
CREATE INDEX IF NOT EXISTS idx_unmatched_payments_created_at ON unmatched_payments (created_at DESC);

-- Payment reversals/refunds: auditable reversal entries linked to the
-- original payment. Original payment record is never modified destructively.
CREATE TABLE IF NOT EXISTS payment_reversals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_transaction_id UUID NOT NULL REFERENCES payment_transactions(id) ON DELETE CASCADE,
    reversal_reference VARCHAR(255) NOT NULL,
    provider_reversal_id VARCHAR(255),
    amount DECIMAL(12, 2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    reason VARCHAR(255) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- pending, completed, failed
    provider_payload JSONB,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_reversal_amount CHECK (amount > 0),
    UNIQUE (reversal_reference)
);

CREATE INDEX IF NOT EXISTS idx_payment_reversals_payment_id ON payment_reversals (payment_transaction_id);
CREATE INDEX IF NOT EXISTS idx_payment_reversals_status ON payment_reversals (status);
CREATE INDEX IF NOT EXISTS idx_payment_reversals_created_at ON payment_reversals (created_at DESC);

-- Trigger to update updated_at on unmatched_payments.
CREATE OR REPLACE FUNCTION update_unmatched_payments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_unmatched_payments_updated_at ON unmatched_payments;
CREATE TRIGGER trigger_update_unmatched_payments_updated_at
    BEFORE UPDATE ON unmatched_payments
    FOR EACH ROW
    EXECUTE FUNCTION update_unmatched_payments_updated_at();

-- Trigger to update updated_at on payment_reversals.
CREATE OR REPLACE FUNCTION update_payment_reversals_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_payment_reversals_updated_at ON payment_reversals;
CREATE TRIGGER trigger_update_payment_reversals_updated_at
    BEFORE UPDATE ON payment_reversals
    FOR EACH ROW
    EXECUTE FUNCTION update_payment_reversals_updated_at();
