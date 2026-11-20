-- Migration: 005_create_roles_table
-- Description: Create roles table for account categories and permissions

CREATE TABLE IF NOT EXISTS roles (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_publicly_assignable BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default roles
INSERT INTO roles (id, name, description, is_system, is_publicly_assignable) VALUES
    ('house_seeker', 'House Seeker', 'User looking for rental properties', FALSE, TRUE),
    ('tenant', 'Tenant', 'User with an active tenancy', FALSE, TRUE),
    ('landlord', 'Landlord', 'Property owner renting out units', FALSE, TRUE),
    ('caretaker', 'Caretaker', 'Property caretaker or manager', FALSE, TRUE),
    ('property_manager', 'Property Manager', 'Professional property management', FALSE, TRUE),
    ('letting_agent', 'Letting Agent', 'Real estate agent for rentals', FALSE, TRUE),
    ('moving_company', 'Moving Company', 'Business providing moving services', FALSE, TRUE),
    ('individual_mover', 'Individual Mover', 'Individual providing moving services', FALSE, TRUE),
    ('garbage_provider', 'Garbage Collection Provider', 'Business providing garbage collection', FALSE, TRUE),
    ('laundry_provider', 'Laundry Provider', 'Business providing laundry services', FALSE, TRUE),
    ('service_provider', 'Service Provider', 'Generic service provider', FALSE, TRUE),
    ('platform_admin', 'Platform Administrator', 'Platform administrator with elevated privileges', TRUE, FALSE),
    ('platform_staff', 'Platform Staff', 'Platform staff member', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_roles_publicly_assignable ON roles (is_publicly_assignable) WHERE is_publicly_assignable = TRUE;