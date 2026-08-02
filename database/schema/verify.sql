-- ============================================================================
-- Video Data Collection & Vendor Management Platform
-- Verification: verify.sql
-- Description: Queries to verify all tables, FKs, indexes, and seed data
-- Run after migration and seed to confirm everything is in place.
-- ============================================================================

-- ============================================================================
-- 1. VERIFY ALL 8 TABLES EXIST
-- Expected: 8 rows
-- ============================================================================
SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN (
      'admins',
      'vendors',
      'candidates',
      'user_sessions',
      'videos',
      'video_locations',
      'qc_reviews',
      'audit_logs'
  )
ORDER BY table_name;

-- ============================================================================
-- 2. VERIFY TABLE ROW COUNTS (should be 0 except admins = 1)
-- ============================================================================
SELECT 'admins' AS table_name, COUNT(*) AS row_count FROM admins
UNION ALL
SELECT 'vendors', COUNT(*) FROM vendors
UNION ALL
SELECT 'candidates', COUNT(*) FROM candidates
UNION ALL
SELECT 'user_sessions', COUNT(*) FROM user_sessions
UNION ALL
SELECT 'videos', COUNT(*) FROM videos
UNION ALL
SELECT 'video_locations', COUNT(*) FROM video_locations
UNION ALL
SELECT 'qc_reviews', COUNT(*) FROM qc_reviews
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs
ORDER BY table_name;

-- ============================================================================
-- 3. VERIFY SEED DATA — DEFAULT ADMIN EXISTS
-- Expected: 1 row with username='admin', email='admin@example.com'
-- ============================================================================
SELECT
    id,
    username,
    email,
    full_name,
    is_active,
    created_at
FROM admins
WHERE username = 'admin';

-- ============================================================================
-- 4. VERIFY ALL FOREIGN KEY CONSTRAINTS
-- Expected: 11 foreign keys
-- ============================================================================
SELECT
    tc.constraint_name,
    tc.table_name AS child_table,
    kcu.column_name AS child_column,
    ccu.table_name AS parent_table,
    ccu.column_name AS parent_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================================
-- 5. VERIFY ALL INDEXES
-- Expected: 12 custom indexes + primary key / unique indexes
-- ============================================================================
SELECT
    indexname,
    tablename,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- ============================================================================
-- 6. VERIFY CHECK CONSTRAINTS
-- Expected: check constraints on videos.status, videos.file_size,
--           videos.duration, qc_reviews.status, audit_logs.actor_role
-- ============================================================================
SELECT
    tc.constraint_name,
    tc.table_name,
    cc.check_clause
FROM information_schema.table_constraints AS tc
JOIN information_schema.check_constraints AS cc
    ON tc.constraint_name = cc.constraint_name
    AND tc.constraint_schema = cc.constraint_schema
WHERE tc.constraint_type = 'CHECK'
  AND tc.table_schema = 'public'
  AND tc.constraint_name NOT LIKE '%_not_null'
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================================
-- 7. VERIFY UNIQUE CONSTRAINTS
-- Expected: unique constraints on admins.username, admins.email,
--           vendors.email, candidates.phone, user_sessions.token,
--           video_locations.video_id, qc_reviews.video_id
-- ============================================================================
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type = 'UNIQUE'
  AND tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_name;

-- ============================================================================
-- 8. VERIFY COLUMN STRUCTURE FOR CORE TABLES
-- Ensures all required columns exist with correct types
-- ============================================================================

-- 8a. Videos table columns
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'videos'
ORDER BY ordinal_position;

-- 8b. QC Reviews table columns
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'qc_reviews'
ORDER BY ordinal_position;

-- ============================================================================
-- 9. VERIFY FOREIGN KEY ENFORCEMENT (should FAIL — that's correct behavior)
-- Uncomment to test; these INSERTs should raise FK violation errors.
-- ============================================================================

-- Test: Insert video with non-existent candidate → should FAIL
-- INSERT INTO videos (candidate_id, vendor_id, file_name, status)
-- VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'test.mp4', 'uploaded');

-- Test: Insert video with invalid status → should FAIL
-- INSERT INTO videos (candidate_id, vendor_id, file_name, status)
-- VALUES (uuid_generate_v4(), uuid_generate_v4(), 'test.mp4', 'invalid_status');

-- ============================================================================
-- VERIFICATION COMPLETE
-- If all queries above return expected results, the schema is correct.
-- ============================================================================
