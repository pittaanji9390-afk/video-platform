-- ============================================================================
-- Video Data Collection & Vendor Management Platform
-- Seed: 001_seed_admin.sql
-- Description: Inserts the default admin account
-- ============================================================================
-- 
-- Default Admin Credentials:
--   Username: admin
--   Email:    admin@example.com
--   Password: (placeholder bcrypt hash — replace before production)
--
-- The password_hash below is a bcrypt placeholder. In production, generate
-- a real hash using bcrypt with a cost factor of 10+.
-- Example (Node.js): await bcrypt.hash('admin123', 10)
-- ============================================================================

INSERT INTO admins (
    id,
    username,
    email,
    password_hash,
    full_name,
    is_active
) VALUES (
    uuid_generate_v4(),
    'admin',
    'admin@example.com',
    '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
    'System Administrator',
    TRUE
)
ON CONFLICT (email) DO NOTHING;

-- ============================================================================
-- SEED COMPLETE
-- ============================================================================
