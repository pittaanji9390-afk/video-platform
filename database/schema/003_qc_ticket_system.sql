-- ============================================================================
-- Video Data Collection & Vendor Management Platform
-- Migration: 003_qc_ticket_system.sql
-- Description: QC Ticket Allocation, Reviewer Activity Tracking & Auto-Reassignment Audit Tables
-- ============================================================================

-- 1. Create QC Tickets Table
CREATE TABLE IF NOT EXISTS qc_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_code VARCHAR(50) NOT NULL UNIQUE,
    video_id VARCHAR(100) NOT NULL,
    candidate_id VARCHAR(100),
    vendor_id VARCHAR(100),
    project_id VARCHAR(100) DEFAULT 'PRJ-DEFAULT',
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status VARCHAR(50) NOT NULL DEFAULT 'pending_qc', -- pending_qc, in_review, qc_approved, qc_rejected, closed
    assigned_reviewer_id VARCHAR(100),
    assigned_reviewer_name VARCHAR(255),
    assignment_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL
);

-- 2. Create Reviewer Activity Tracking Table
CREATE TABLE IF NOT EXISTS reviewer_activity (
    reviewer_id VARCHAR(100) PRIMARY KEY,
    reviewer_name VARCHAR(255) NOT NULL,
    reviewer_email VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_dashboard_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_review_submission_at TIMESTAMP WITH TIME ZONE NULL,
    last_active_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create Ticket Assignment & Reassignment Audit Log Table
CREATE TABLE IF NOT EXISTS ticket_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES qc_tickets(id) ON DELETE CASCADE,
    video_id VARCHAR(100) NOT NULL,
    previous_reviewer_id VARCHAR(100),
    previous_reviewer_name VARCHAR(255),
    new_reviewer_id VARCHAR(100) NOT NULL,
    new_reviewer_name VARCHAR(255) NOT NULL,
    assignment_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reassignment_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason VARCHAR(100) NOT NULL DEFAULT 'INITIAL_ASSIGNMENT', -- INITIAL_ASSIGNMENT, AUTO_REASSIGNMENT_INACTIVITY, MANUAL_REASSIGNMENT
    performed_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM', -- SYSTEM, ADMIN, QC_LEAD
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create Admin QC System Configurations Table
CREATE TABLE IF NOT EXISTS admin_qc_configs (
    key VARCHAR(100) PRIMARY KEY,
    value VARCHAR(255) NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert Default Admin Configurations if not present
INSERT INTO admin_qc_configs (key, value, description) VALUES
('auto_assignment_enabled', 'true', 'Automatically assign tickets upon video upload'),
('auto_reassignment_enabled', 'true', 'Automatically reassign tickets of inactive reviewers'),
('inactivity_timeout_hours', '24', 'Hours of inactivity before triggering ticket reassignment'),
('max_tickets_per_reviewer', '50', 'Maximum pending/active tickets per QC reviewer'),
('assignment_strategy', 'LEAST_WORKLOAD', 'Ticket assignment distribution algorithm')
ON CONFLICT (key) DO NOTHING;

-- Seed Sample Active QC Team Members in Reviewer Activity
INSERT INTO reviewer_activity (reviewer_id, reviewer_name, reviewer_email, is_active, is_available, last_active_timestamp) VALUES
('a0000000-0000-0000-0000-000000000001', 'QC Lead Specialist', 'qc@videoplatform.com', TRUE, TRUE, NOW()),
('a0000000-0000-0000-0000-000000000002', 'QC Reviewer Specialist', 'qc.reviewer@videoplatform.com', TRUE, TRUE, NOW()),
('a0000000-0000-0000-0000-000000000003', 'Priya Sharma (QC Specialist)', 'priya.qc@videoplatform.com', TRUE, TRUE, NOW())
ON CONFLICT (reviewer_id) DO NOTHING;

-- Indexes for Ultra-Fast Queries
CREATE INDEX IF NOT EXISTS idx_qc_tickets_status ON qc_tickets (status);
CREATE INDEX IF NOT EXISTS idx_qc_tickets_reviewer ON qc_tickets (assigned_reviewer_id);
CREATE INDEX IF NOT EXISTS idx_ticket_assignments_ticket ON ticket_assignments (ticket_id);
CREATE INDEX IF NOT EXISTS idx_reviewer_activity_last_active ON reviewer_activity (last_active_timestamp);
