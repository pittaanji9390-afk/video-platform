# Database Documentation

## Overview

PostgreSQL database for the Video Data Collection & Vendor Management Platform.
Contains 11 tables covering admins, vendors, candidates, video management, quality control, payments, and audit logging.

---

## Entity Relationship Diagram

```
┌──────────────┐
│    admins     │
│──────────────│
│ PK: id (UUID)│
│ username      │
│ email         │
│ password_hash │
└──────┬───────┘
       │ reviews (qc_reviews.reviewer_id)
       │ creates (vendors.created_by)
       │
       ▼
┌──────────────┐       1:N        ┌────────────────┐
│  qc_reviews  │◄────────────────│     videos      │
│──────────────│                  │────────────────│
│ FK: video_id │                  │ FK: candidate_id │
│ FK: reviewer_id                 │ FK: vendor_id    │
└──────────────┘                  │ s3_url, status   │
                                  └───┬──────┬──────┘
                                      │      │
                          ┌───────────┘      └───────────┐
                          ▼                              ▼
                 ┌────────────────┐            ┌──────────────────┐
                 │  candidates    │            │ video_locations   │
                 │────────────────│            │──────────────────│
                 │ FK: vendor_id  │            │ FK: video_id      │
                 └───────┬────────┘            └──────────────────┘
                         │
                         ▼
                 ┌────────────────┐
                 │ user_sessions  │
                 │────────────────│
                 │ FK: candidate_id │
                  └────────────────┘

┌──────────────┐
│  audit_logs  │  (standalone — polymorphic actor reference)
└──────────────┘
```

---

## Tables

| # | Table | Description |
|---|-------|-------------|
| 1 | `admins` | Platform administrators |
| 2 | `vendors` | Companies/individuals managing video collection |
| 3 | `candidates` | Individuals recording/uploading videos |
| 4 | `user_sessions` | Active login sessions for candidates |
| 5 | `videos` | Video metadata (S3 URL, duration, status, GPS) |
| 6 | `video_locations` | Extended location metadata per video |
| 7 | `qc_reviews` | Quality control reviews by admins |
| 8 | `audit_logs` | System-wide audit trail |

---

## Common Column Conventions

Every table includes:
- `id` — UUID primary key (`uuid_generate_v4()`)
- `created_at` — Record creation timestamp
- `updated_at` — Last update timestamp
- `deleted_at` — Soft delete timestamp (NULL = active)

---

## Folder Structure

```
database/
├── migrations/
│   └── 001_initial_schema.sql   # Full DDL: tables, FKs, indexes, constraints
├── seeds/
│   └── 001_seed_admin.sql       # Default admin account
├── schema/
│   ├── schema.sql               # Reference copy of the full schema
│   └── verify.sql               # Verification queries
└── README.md                    # This file
```

---

## How to Run

### Prerequisites
- PostgreSQL 14+ installed and running locally
- `psql` CLI available on PATH

### Step 1: Create Database
```bash
psql -U postgres -c "CREATE DATABASE videoplatform;"
```

### Step 2: Run Migration
```bash
psql -U postgres -d videoplatform -f database/migrations/001_initial_schema.sql
```

### Step 3: Run Seed Data
```bash
psql -U postgres -d videoplatform -f database/seeds/001_seed_admin.sql
```

### Step 4: Verify
```bash
psql -U postgres -d videoplatform -f database/schema/verify.sql
```

---

## Migration Guidelines

1. **Never modify an existing migration file** — create a new numbered file instead (e.g., `002_add_column.sql`).
2. **All schema changes must go through migrations** — no direct manual `ALTER TABLE` in production.
3. **Test migrations locally** before applying to staging/production.
4. **Use standard PostgreSQL syntax** — must be compatible with AWS RDS PostgreSQL.
