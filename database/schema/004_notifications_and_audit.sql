-- ============================================================================
-- Video Data Collection & Vendor Management Platform
-- Migration: 004_notifications_and_audit.sql
-- Description: Real-Time Event Notifications & Audit Trail Logging Tables
-- ============================================================================

-- 1. Create Notifications Table if not exists
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(100),
    user_role VARCHAR(50) DEFAULT 'candidate',
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    event_type VARCHAR(100) DEFAULT 'system',
    related_video_id VARCHAR(100),
    related_task_id VARCHAR(100),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure all columns exist for existing tables
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_role VARCHAR(50) DEFAULT 'candidate';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS event_type VARCHAR(100) DEFAULT 'system';
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS related_video_id VARCHAR(100);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS related_task_id VARCHAR(100);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at TIMESTAMP WITH TIME ZONE NULL;

-- 2. Create Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    action VARCHAR(100) NOT NULL,
    actor_id VARCHAR(100),
    actor_name VARCHAR(255),
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(100) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for Ultra-Fast Event De-duplication & Read-State Queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_event ON notifications (user_id, event_type, related_video_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications (is_read);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs (resource_type, resource_id);
