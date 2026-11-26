-- Migration: 073_seed_listing_and_garbage_permissions
-- Description: Seed listing, garbage, and tenant management permissions

INSERT INTO permissions (id, name, description, category, is_system) VALUES
-- Listing permissions
('listing.view', 'View Listing', 'View published property listings', 'listing', FALSE),
('listing.create', 'Create Listing', 'Create new property listings', 'listing', FALSE),
('listing.update', 'Update Listing', 'Update property listing details', 'listing', FALSE),
('listing.publish', 'Publish Listing', 'Publish/unpublish property listings', 'listing', FALSE),
('listing.pause', 'Pause Listing', 'Pause/resume property listings', 'listing', FALSE),
('listing.withdraw', 'Withdraw Listing', 'Withdraw property listings from market', 'listing', FALSE),
('listing.archive', 'Archive Listing', 'Archive property listings', 'listing', FALSE),

-- Garbage management permissions
('garbage.view', 'View Garbage Services', 'View garbage providers and collection requests', 'garbage', FALSE),
('garbage.create', 'Create Garbage Request', 'Create garbage collection requests', 'garbage', FALSE),
('garbage.manage', 'Manage Garbage Services', 'Manage garbage providers and assignments', 'garbage', FALSE)
ON CONFLICT (id) DO NOTHING;
