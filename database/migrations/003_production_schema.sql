-- ============================================================================
-- Video Data Collection & Vendor Management Platform
-- Migration: 003_production_schema.sql
-- Description: Production schema fixes — all missing tables & column patches
-- Run: psql $DATABASE_URL -f 003_production_schema.sql
-- ============================================================================

-- Enable UUID extension (safe no-op if already exists)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- PATCH 1: Fix videos.status CHECK constraint to include all operational states
-- Standardized to lowercase only
-- ============================================================================
ALTER TABLE videos DROP CONSTRAINT IF EXISTS chk_videos_status;
ALTER TABLE videos
  ADD CONSTRAINT chk_videos_status CHECK (
    status IN (
      'pending', 'uploaded', 'under_review',
      'pending_qc', 'assigned_qc', 'in_review',
      'qc_approved', 'qc_rejected',
      'approved', 'rejected', 'deleted'
    )
  );

-- ============================================================================
-- PATCH 2: Add password_hash to candidates (needed for email/password login)
-- ============================================================================
ALTER TABLE candidates ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

-- ============================================================================
-- PATCH 3: Extend qc_reviews with score & comment columns
-- ============================================================================
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS qc_reviewer_id  UUID;
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS audio_score     DECIMAL(4,2) DEFAULT 0;
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS lighting_score  DECIMAL(4,2) DEFAULT 0;
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS framing_score   DECIMAL(4,2) DEFAULT 0;
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS env_match_score DECIMAL(4,2) DEFAULT 0;
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS qc_comments     TEXT;
ALTER TABLE qc_reviews ADD COLUMN IF NOT EXISTS admin_comments  TEXT;
-- Fix qc_reviews status CHECK to match operational values (lowercase only)
ALTER TABLE qc_reviews DROP CONSTRAINT IF EXISTS chk_qc_reviews_status;
ALTER TABLE qc_reviews
  ADD CONSTRAINT chk_qc_reviews_status CHECK (
    status IN ('approved','rejected','qc_approved','qc_rejected')
  );

-- ============================================================================
-- 5. USERS TABLE
-- Generic login table for vendor portal users & QC reviewers created by Admin.
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255)  NOT NULL,
    password_hash   VARCHAR(255)  NOT NULL,
    full_name       VARCHAR(200)  NOT NULL,
    role            VARCHAR(50)   NOT NULL DEFAULT 'vendor',
    vendor_id       UUID,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_by      UUID,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_users_role CHECK (role IN ('admin','vendor','candidate','qc_team','qc_reviewer'))
);
CREATE INDEX IF NOT EXISTS idx_users_email  ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_role   ON users (role);

-- Add foreign keys for users table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_vendor') THEN
    ALTER TABLE users ADD CONSTRAINT fk_users_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_users_created_by') THEN
    ALTER TABLE users ADD CONSTRAINT fk_users_created_by FOREIGN KEY (created_by) REFERENCES admins(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 6. REFRESH TOKENS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID         NOT NULL,
    token       TEXT         NOT NULL,
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_refresh_tokens_token UNIQUE (token)
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens (user_id);

-- Add foreign key for refresh_tokens
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_refresh_tokens_user') THEN
    ALTER TABLE refresh_tokens ADD CONSTRAINT fk_refresh_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ============================================================================
-- 7. NOTIFICATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS notifications (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID,
    user_role           VARCHAR(50)   NOT NULL DEFAULT 'candidate',
    title               VARCHAR(300)  NOT NULL,
    message             TEXT          NOT NULL,
    event_type          VARCHAR(100)  NOT NULL DEFAULT 'system',
    related_video_id    UUID,
    related_task_id     UUID,
    is_read             BOOLEAN       NOT NULL DEFAULT FALSE,
    read_at             TIMESTAMPTZ,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id   ON notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_role      ON notifications (user_role);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read   ON notifications (is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created   ON notifications (created_at DESC);

-- Add foreign key for notifications.related_video_id
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_notifications_video') THEN
    ALTER TABLE notifications ADD CONSTRAINT fk_notifications_video FOREIGN KEY (related_video_id) REFERENCES videos(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 8. QC_TICKETS TABLE
-- Auto-created when a candidate uploads a video. 
-- ============================================================================
CREATE TABLE IF NOT EXISTS qc_tickets (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_code             VARCHAR(50)   NOT NULL,
    video_id                UUID          NOT NULL,
    candidate_id            UUID,
    vendor_id               UUID,
    project_id              VARCHAR(100)  DEFAULT 'PRJ-DEFAULT',
    upload_date             TIMESTAMPTZ   DEFAULT NOW(),
    status                  VARCHAR(50)   NOT NULL DEFAULT 'pending_qc',
    assigned_reviewer_id    UUID,
    assigned_reviewer_name  VARCHAR(200),
    assignment_time         TIMESTAMPTZ,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ,

    CONSTRAINT uq_qc_tickets_ticket_code  UNIQUE (ticket_code),
    CONSTRAINT chk_qc_tickets_status CHECK (status IN (
      'pending_qc','assigned','in_review','qc_approved','qc_rejected','closed'
    ))
);
CREATE INDEX IF NOT EXISTS idx_qc_tickets_video_id        ON qc_tickets (video_id);
CREATE INDEX IF NOT EXISTS idx_qc_tickets_reviewer_id     ON qc_tickets (assigned_reviewer_id);
CREATE INDEX IF NOT EXISTS idx_qc_tickets_status          ON qc_tickets (status);

-- Add foreign keys for qc_tickets
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_qc_tickets_video') THEN
    ALTER TABLE qc_tickets ADD CONSTRAINT fk_qc_tickets_video FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_qc_tickets_candidate') THEN
    ALTER TABLE qc_tickets ADD CONSTRAINT fk_qc_tickets_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_qc_tickets_vendor') THEN
    ALTER TABLE qc_tickets ADD CONSTRAINT fk_qc_tickets_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 9. TICKET_ASSIGNMENTS TABLE
-- Full audit trail of every ticket assignment/reassignment.
-- ============================================================================
CREATE TABLE IF NOT EXISTS ticket_assignments (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id               UUID,
    video_id                UUID,
    previous_reviewer_id    UUID,
    previous_reviewer_name  VARCHAR(200),
    new_reviewer_id         UUID,
    new_reviewer_name       VARCHAR(200),
    assignment_time         TIMESTAMPTZ  DEFAULT NOW(),
    reassignment_time       TIMESTAMPTZ,
    reason                  VARCHAR(100) DEFAULT 'INITIAL_ASSIGNMENT',
    performed_by            VARCHAR(100) DEFAULT 'SYSTEM',
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ticket_assignments_ticket ON ticket_assignments (ticket_id);

-- Add foreign key for ticket_assignments
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ticket_assignments_ticket') THEN
    ALTER TABLE ticket_assignments ADD CONSTRAINT fk_ticket_assignments_ticket FOREIGN KEY (ticket_id) REFERENCES qc_tickets(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================================================
-- 10. REVIEWER_ACTIVITY TABLE
-- Tracks QC reviewer login, dashboard, and review submission activity.
-- ============================================================================
CREATE TABLE IF NOT EXISTS reviewer_activity (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reviewer_id                 UUID         NOT NULL,
    reviewer_name               VARCHAR(200),
    reviewer_email              VARCHAR(255),
    password_hash               VARCHAR(255),
    is_active                   BOOLEAN      NOT NULL DEFAULT TRUE,
    is_available                BOOLEAN      NOT NULL DEFAULT TRUE,
    last_login_at               TIMESTAMPTZ  DEFAULT NOW(),
    last_dashboard_activity_at  TIMESTAMPTZ  DEFAULT NOW(),
    last_review_submission_at   TIMESTAMPTZ,
    last_active_timestamp       TIMESTAMPTZ  DEFAULT NOW(),
    created_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at                  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_reviewer_activity_reviewer_id UNIQUE (reviewer_id)
);
CREATE INDEX IF NOT EXISTS idx_reviewer_activity_active ON reviewer_activity (is_active, is_available);

-- ============================================================================
-- 11. ADMIN_QC_CONFIGS TABLE
-- Key/value configuration store for QC system settings.
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_qc_configs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key         VARCHAR(100)  NOT NULL,
    value       TEXT          NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_admin_qc_configs_key UNIQUE (key)
);

-- Seed default QC configuration values
INSERT INTO admin_qc_configs (key, value, description) VALUES
  ('auto_assignment_enabled',   'true',            'Enable automatic ticket assignment to QC reviewers on upload'),
  ('auto_reassignment_enabled', 'true',            'Enable auto-reassignment when reviewer inactive > threshold hours'),
  ('inactivity_timeout_hours',  '24',              'Hours of inactivity before ticket reassignment triggers'),
  ('max_tickets_per_reviewer',  '50',              'Maximum concurrent tickets per QC reviewer'),
  ('assignment_strategy',       'LEAST_WORKLOAD',  'Algorithm used for ticket distribution: LEAST_WORKLOAD | ROUND_ROBIN')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- SEED: Default Admin Account (admin@gmail.com / admin123)
-- NOTE: This bcrypt hash is for the password "admin123"
-- ============================================================================
INSERT INTO admins (id, email, password_hash, full_name, username, is_active, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'admin@gmail.com',
  '$2b$10$YZ2dFETo5bvXJ8g9o5/WVeW3QffZfTEeUfzAiLkiOPl/./t5Xzwq',
  'System Administrator',
  'admin',
  TRUE,
  NOW(),
  NOW()
) ON CONFLICT (email) DO UPDATE
    SET password_hash = EXCLUDED.password_hash,
        full_name = EXCLUDED.full_name,
        is_active = TRUE,
        updated_at = NOW();

-- ============================================================================
-- SEED: QC Reviewer Entry in reviewer_activity
-- ============================================================================
INSERT INTO reviewer_activity (
  reviewer_id, reviewer_name, reviewer_email,
  password_hash, is_active, is_available, created_at, updated_at
) VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'QC Lead Specialist',
  'qcteam@gmail.com',
  '$2b$10$YZ2dFETo5bvXJ8g9o5/WVeW3QffZfTEeUfzAiLkiOPl/./t5Xzwq',
  TRUE, TRUE, NOW(), NOW()
) ON CONFLICT (reviewer_id) DO UPDATE
    SET reviewer_email = EXCLUDED.reviewer_email,
        password_hash = EXCLUDED.password_hash,
        updated_at = NOW();

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
