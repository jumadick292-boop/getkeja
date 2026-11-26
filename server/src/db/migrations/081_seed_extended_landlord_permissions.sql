-- Migration: 081_seed_extended_landlord_permissions
-- Description: Seed extended landlord, property, enquiry, communication, proposal, financial, maintenance permissions

INSERT INTO permissions (id, name, description, category, is_system) VALUES
-- Property management permissions
('property.view', 'View Property', 'View property details and portfolio', 'property', FALSE),
('property.create', 'Create Property', 'Register new properties', 'property', FALSE),
('property.update', 'Update Property', 'Edit property details', 'property', FALSE),
('property.archive', 'Archive Property', 'Archive properties', 'property', FALSE),
('property.manage_ownership', 'Manage Property Ownership', 'Manage ownership records and shares', 'property', FALSE),
('property.manage_representatives', 'Manage Property Representatives', 'Manage staff and representative assignments', 'property', FALSE),

-- Unit management permissions
('unit.view', 'View Unit', 'View unit details and availability', 'unit', FALSE),
('unit.create', 'Create Unit', 'Create new units within properties', 'unit', FALSE),
('unit.update', 'Update Unit', 'Edit unit details and pricing', 'unit', FALSE),
('unit.archive', 'Archive Unit', 'Archive units', 'unit', FALSE),

-- Enquiry management permissions
('enquiry.view', 'View Enquiry', 'View property enquiries', 'enquiry', FALSE),
('enquiry.create', 'Create Enquiry', 'Create property enquiries', 'enquiry', FALSE),
('enquiry.update', 'Update Enquiry', 'Update enquiry status and notes', 'enquiry', FALSE),
('enquiry.assign', 'Assign Enquiry', 'Assign enquiries to staff', 'enquiry', FALSE),
('enquiry.close', 'Close Enquiry', 'Close or archive enquiries', 'enquiry', FALSE),

-- Communication permissions
('conversation.view', 'View Conversation', 'View conversations', 'communication', FALSE),
('conversation.create', 'Create Conversation', 'Start new conversations', 'communication', FALSE),
('message.send', 'Send Message', 'Send messages in conversations', 'communication', FALSE),
('message.read', 'Read Message', 'Mark messages as read', 'communication', FALSE),

-- Rental proposal permissions
('proposal.view', 'View Rental Proposal', 'View rental proposals', 'proposal', FALSE),
('proposal.create', 'Create Rental Proposal', 'Create rental proposals', 'proposal', FALSE),
('proposal.update', 'Update Rental Proposal', 'Update rental proposals', 'proposal', FALSE),
('proposal.accept', 'Accept Rental Proposal', 'Accept rental proposals', 'proposal', FALSE),
('proposal.decline', 'Decline Rental Proposal', 'Decline rental proposals', 'proposal', FALSE),

-- Financial management permissions
('invoice.view', 'View Invoice', 'View invoices', 'financial', FALSE),
('invoice.create', 'Create Invoice', 'Generate invoices', 'financial', FALSE),
('invoice.update', 'Update Invoice', 'Update invoice details', 'financial', FALSE),
('payment.record', 'Record Payment', 'Record payment transactions', 'financial', FALSE),
('payment.reconcile', 'Reconcile Payment', 'Reconcile payment callbacks', 'financial', FALSE),
('ledger.view', 'View Rent Ledger', 'View rent ledger entries', 'financial', FALSE),
('deposit.view', 'View Deposit', 'View tenant deposits', 'financial', FALSE),
('deposit.manage', 'Manage Deposit', 'Manage deposit records and refunds', 'financial', FALSE),
('arrears.view', 'View Arrears', 'View arrears and overdue invoices', 'financial', FALSE),
('expense.view', 'View Expense', 'View property expenses', 'financial', FALSE),
('expense.create', 'Create Expense', 'Record property expenses', 'financial', FALSE),
('report.view', 'View Report', 'View property and financial reports', 'reporting', FALSE),
('report.export', 'Export Report', 'Export reports to PDF/CSV', 'reporting', FALSE),

-- Maintenance permissions
('maintenance.view', 'View Maintenance', 'View maintenance requests and issues', 'maintenance', FALSE),
('maintenance.create', 'Create Maintenance', 'Create maintenance requests', 'maintenance', FALSE),
('maintenance.update', 'Update Maintenance', 'Update maintenance status', 'maintenance', FALSE),
('maintenance.assign', 'Assign Maintenance', 'Assign maintenance to staff/providers', 'maintenance', FALSE),
('maintenance.approve', 'Approve Maintenance', 'Approve maintenance estimates and costs', 'maintenance', FALSE),

-- Lease and document permissions
('lease.view', 'View Lease', 'View rental agreements and lease documents', 'lease', FALSE),
('lease.create', 'Create Lease', 'Create rental agreements', 'lease', FALSE),
('lease.update', 'Update Lease', 'Update lease details', 'lease', FALSE),
('lease.renew', 'Renew Lease', 'Process lease renewals', 'lease', FALSE),
('lease.terminate', 'Terminate Lease', 'Process lease terminations', 'lease', FALSE),
('document.view', 'View Document', 'View property and lease documents', 'document', FALSE),
('document.upload', 'Upload Document', 'Upload documents', 'document', FALSE),
('document.download', 'Download Document', 'Download private documents', 'document', FALSE),

-- Tenant onboarding permissions
('onboarding.view', 'View Onboarding', 'View tenant onboarding records', 'onboarding', FALSE),
('onboarding.initiate', 'Initiate Onboarding', 'Start tenant onboarding process', 'onboarding', FALSE),
('onboarding.complete', 'Complete Onboarding', 'Complete tenant onboarding', 'onboarding', FALSE),

-- Inspection permissions
('inspection.view', 'View Inspection', 'View move-in and move-out inspections', 'inspection', FALSE),
('inspection.create', 'Create Inspection', 'Create inspection records', 'inspection', FALSE)
ON CONFLICT (id) DO NOTHING;

-- Map new permissions to landlord role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'landlord', p.id
FROM permissions p
WHERE p.id IN (
    'property.view', 'property.create', 'property.update', 'property.archive',
    'property.manage_ownership', 'property.manage_representatives',
    'unit.view', 'unit.create', 'unit.update', 'unit.archive',
    'enquiry.view', 'enquiry.create', 'enquiry.update', 'enquiry.assign', 'enquiry.close',
    'conversation.view', 'conversation.create', 'message.send', 'message.read',
    'proposal.view', 'proposal.create', 'proposal.update', 'proposal.accept', 'proposal.decline',
    'invoice.view', 'invoice.create', 'invoice.update',
    'payment.record', 'payment.reconcile', 'ledger.view',
    'deposit.view', 'deposit.manage',
    'arrears.view',
    'expense.view', 'expense.create',
    'report.view', 'report.export',
    'maintenance.view', 'maintenance.create', 'maintenance.update', 'maintenance.assign', 'maintenance.approve',
    'lease.view', 'lease.create', 'lease.update', 'lease.renew', 'lease.terminate',
    'document.view', 'document.upload', 'document.download',
    'onboarding.view', 'onboarding.initiate', 'onboarding.complete',
    'inspection.view', 'inspection.create'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Map to property_manager role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'property_manager', p.id
FROM permissions p
WHERE p.id IN (
    'property.view', 'property.update',
    'unit.view', 'unit.create', 'unit.update',
    'enquiry.view', 'enquiry.create', 'enquiry.update', 'enquiry.assign', 'enquiry.close',
    'conversation.view', 'conversation.create', 'message.send', 'message.read',
    'proposal.view', 'proposal.create', 'proposal.update', 'proposal.accept', 'proposal.decline',
    'invoice.view', 'invoice.create', 'invoice.update',
    'payment.record', 'ledger.view',
    'deposit.view', 'deposit.manage',
    'arrears.view',
    'expense.view', 'expense.create',
    'report.view',
    'maintenance.view', 'maintenance.create', 'maintenance.update', 'maintenance.assign',
    'lease.view', 'lease.create', 'lease.update',
    'document.view', 'document.upload', 'document.download',
    'onboarding.view', 'onboarding.initiate', 'onboarding.complete',
    'inspection.view', 'inspection.create'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Map to letting_agent role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'letting_agent', p.id
FROM permissions p
WHERE p.id IN (
    'property.view',
    'unit.view',
    'enquiry.view', 'enquiry.create', 'enquiry.update', 'enquiry.assign',
    'conversation.view', 'conversation.create', 'message.send', 'message.read',
    'proposal.view', 'proposal.create', 'proposal.update',
    'invoice.view',
    'payment.record',
    'document.view', 'document.upload',
    'onboarding.view', 'onboarding.initiate'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Map to caretaker role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'caretaker', p.id
FROM permissions p
WHERE p.id IN (
    'property.view',
    'unit.view',
    'enquiry.view',
    'conversation.view', 'message.send', 'message.read',
    'maintenance.view', 'maintenance.create', 'maintenance.update',
    'document.view'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Map to organization_admin role (all permissions within org scope)
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'organization_admin', p.id
FROM permissions p
ON CONFLICT (role_id, permission_id) DO NOTHING;
