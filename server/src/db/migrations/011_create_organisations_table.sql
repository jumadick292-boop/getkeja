-- Migration: 011_create_organisations_table
-- Description: Create organisations table for business entities

CREATE TABLE IF NOT EXISTS organisations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) NOT NULL UNIQUE,
    type VARCHAR(50) NOT NULL, -- 'letting_agency', 'property_management', 'moving_company', 'garbage_collection', 'laundry', 'other'
    description TEXT,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    county VARCHAR(100),
    country VARCHAR(2) DEFAULT 'KE',
    registration_number VARCHAR(100),
    tax_id VARCHAR(100),
    logo_url VARCHAR(500),
    website_url VARCHAR(500),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'in_review', 'verified', 'rejected'
    verification_notes TEXT,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_organisations_slug ON organisations (slug);
CREATE INDEX IF NOT EXISTS idx_organisations_type ON organisations (type);
CREATE INDEX IF NOT EXISTS idx_organisations_verification_status ON organisations (verification_status);