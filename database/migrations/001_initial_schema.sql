-- ============================================================================
-- Video Data Collection & Vendor Management Platform
-- Migration: 001_initial_schema.sql
-- Description: Creates all 11 tables, foreign keys, indexes, and constraints
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. ADMINS TABLE
-- Platform administrators who manage vendors, review videos, and oversee ops.
-- ============================================================================
CREATE TABLE admins (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(100),
    email           VARCHAR(255)  NOT NULL,
    phone           VARCHAR(20),
    password_hash   VARCHAR(255)  NOT NULL,
    full_name       VARCHAR(200)  NOT NULL,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_admins_email UNIQUE (email)
);

-- ============================================================================
-- 2. VENDORS TABLE
-- Companies/individuals who recruit candidates and manage video collection.
-- Created by admins.
-- ============================================================================
CREATE TABLE vendors (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_code     VARCHAR(50)   NOT NULL,
    company_name    VARCHAR(200)  NOT NULL,
    contact_person  VARCHAR(200)  NOT NULL,
    email           VARCHAR(255)  NOT NULL,
    phone           VARCHAR(20),
    address         TEXT,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_by      UUID,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_vendors_vendor_code UNIQUE (vendor_code),
    CONSTRAINT uq_vendors_email       UNIQUE (email),
    CONSTRAINT fk_vendors_created_by FOREIGN KEY (created_by)
        REFERENCES admins (id) ON DELETE SET NULL
);

-- ============================================================================
-- 3. CANDIDATES TABLE
-- Individuals assigned by vendors to record and upload videos.
-- Each candidate belongs to exactly one vendor.
-- ============================================================================
CREATE TABLE candidates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_id       UUID          NOT NULL,
    full_name       VARCHAR(200)  NOT NULL,
    email           VARCHAR(255),
    phone           VARCHAR(20)   NOT NULL,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_candidates_phone UNIQUE (phone),
    CONSTRAINT fk_candidates_vendor FOREIGN KEY (vendor_id)
        REFERENCES vendors (id) ON DELETE CASCADE
);

-- ============================================================================
-- 4. USER_SESSIONS TABLE
-- Active login sessions for candidates.
-- ============================================================================
CREATE TABLE user_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id    UUID          NOT NULL,
    token           VARCHAR(500)  NOT NULL,
    device_info     VARCHAR(500),
    ip_address      VARCHAR(45),
    expires_at      TIMESTAMPTZ   NOT NULL,
    is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_user_sessions_token UNIQUE (token),
    CONSTRAINT fk_user_sessions_candidate FOREIGN KEY (candidate_id)
        REFERENCES candidates (id) ON DELETE CASCADE
);

-- ============================================================================
-- 6. VIDEOS TABLE
-- Core table storing metadata for every video recorded and uploaded.
-- Denormalized vendor_id for query performance (canonical source is
-- candidates.vendor_id, but joins on large video tables are expensive).
-- ============================================================================
CREATE TABLE videos (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_id    UUID          NOT NULL,
    vendor_id       UUID          NOT NULL,
    title           VARCHAR(255),
    description     TEXT,
    s3_url          VARCHAR(1000),
    file_name       VARCHAR(500),
    local_path      VARCHAR(1000),
    file_size       BIGINT,
    duration        INTEGER,
    recording_date  TIMESTAMPTZ,
    upload_date     TIMESTAMPTZ,
    status          VARCHAR(50)   NOT NULL DEFAULT 'pending',
    environment_tag VARCHAR(100),
    latitude        DECIMAL(10, 8),
    longitude       DECIMAL(11, 8),
    device_id       VARCHAR(255),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT chk_videos_file_size CHECK (file_size IS NULL OR file_size >= 0),
    CONSTRAINT chk_videos_duration  CHECK (duration IS NULL OR duration >= 0),
    CONSTRAINT chk_videos_status    CHECK (status IN ('pending', 'uploaded', 'under_review', 'approved', 'rejected')),
    CONSTRAINT fk_videos_candidate  FOREIGN KEY (candidate_id)
        REFERENCES candidates (id) ON DELETE CASCADE,
    CONSTRAINT fk_videos_vendor     FOREIGN KEY (vendor_id)
        REFERENCES vendors (id) ON DELETE CASCADE
);

-- ============================================================================
-- 7. VIDEO_LOCATIONS TABLE
-- Extended location metadata for videos (address, city, state, country).
-- One-to-one with videos (UNIQUE constraint on video_id).
-- ============================================================================
CREATE TABLE video_locations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    video_id        UUID          NOT NULL,
    latitude        DECIMAL(10, 8),
    longitude       DECIMAL(11, 8),
    address         TEXT,
    city            VARCHAR(100),
    state           VARCHAR(100),
    country         VARCHAR(100),
    pincode         VARCHAR(20),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_video_locations_video UNIQUE (video_id),
    CONSTRAINT fk_video_locations_video FOREIGN KEY (video_id)
        REFERENCES videos (id) ON DELETE CASCADE
);

-- ============================================================================
-- 8. QC_REVIEWS TABLE
-- Quality control review records. One review per video (UNIQUE on video_id).
-- Reviewer is always an admin.
-- ============================================================================
CREATE TABLE qc_reviews (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    video_id        UUID          NOT NULL,
    reviewer_id     UUID,
    reviewer_name   VARCHAR(200),
    status          VARCHAR(50)   NOT NULL,
    reject_reason   TEXT,
    reviewed_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT uq_qc_reviews_video  UNIQUE (video_id),
    CONSTRAINT chk_qc_reviews_status CHECK (status IN ('approved', 'rejected')),
    CONSTRAINT fk_qc_reviews_video   FOREIGN KEY (video_id)
        REFERENCES videos (id) ON DELETE CASCADE,
    CONSTRAINT fk_qc_reviews_reviewer FOREIGN KEY (reviewer_id)
        REFERENCES admins (id) ON DELETE SET NULL
);

-- ============================================================================
-- 9. AUDIT_LOGS TABLE
-- System-wide audit trail for all significant actions.
-- actor_id is a plain UUID (polymorphic — can be admin, vendor, or candidate).
-- No FK to avoid circular dependencies; actor_role disambiguates.
-- ============================================================================
CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id        UUID          NOT NULL,
    actor_role      VARCHAR(50)   NOT NULL,
    action          VARCHAR(255)  NOT NULL,
    resource_type   VARCHAR(100),
    resource_id     UUID,
    details         JSONB,
    ip_address      VARCHAR(45),
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,

    CONSTRAINT chk_audit_logs_actor_role CHECK (actor_role IN ('admin', 'vendor', 'candidate', 'system'))
);


-- ============================================================================
-- INDEXES
-- ============================================================================

-- Candidates: lookup by vendor
CREATE INDEX idx_candidates_vendor_id ON candidates (vendor_id);

-- Videos: lookup by candidate, vendor, status, dates
CREATE INDEX idx_videos_candidate_id  ON videos (candidate_id);
CREATE INDEX idx_videos_vendor_id     ON videos (vendor_id);
CREATE INDEX idx_videos_status        ON videos (status);
CREATE INDEX idx_videos_upload_date   ON videos (upload_date);
CREATE INDEX idx_videos_recording_date ON videos (recording_date);

-- User Sessions: lookup by candidate
CREATE INDEX idx_user_sessions_candidate_id ON user_sessions (candidate_id);

-- Audit Logs: lookup by actor, by resource
CREATE INDEX idx_audit_logs_actor_id  ON audit_logs (actor_id);
CREATE INDEX idx_audit_logs_resource  ON audit_logs (resource_type, resource_id);


-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
