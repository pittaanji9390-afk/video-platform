require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const bcrypt = require('bcryptjs');
const db = require('./connection');

async function seedNeonDatabase() {
  console.log('🌱 Starting Clean PostgreSQL Database Seeding...');

  try {
    const adminPasswordHash = await bcrypt.hash('admin123', 10);
    const vendorPasswordHash = await bcrypt.hash('vendor123', 10);
    const candidatePasswordHash = await bcrypt.hash('candidate123', 10);
    const qcPasswordHash = await bcrypt.hash('qcteam123', 10);

    // Ensure password_hash, password, user_role, role, project_id, event_type, type, and candidate_code columns exist on all tables
    await db.query('ALTER TABLE candidates ADD COLUMN IF NOT EXISTS candidate_code VARCHAR(50);').catch(() => {});
    await db.query('ALTER TABLE qc_tickets ADD COLUMN IF NOT EXISTS project_id VARCHAR(100);').catch(() => {});
    await db.query('ALTER TABLE vendors ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE vendors ADD COLUMN IF NOT EXISTS password VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE candidates ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE candidates ADD COLUMN IF NOT EXISTS password VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS password VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE admins ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE admins ADD COLUMN IF NOT EXISTS password VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE reviewer_activity ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE reviewer_activity ADD COLUMN IF NOT EXISTS password VARCHAR(255);').catch(() => {});
    await db.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS user_role VARCHAR(50);').catch(() => {});
    await db.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS role VARCHAR(50);').catch(() => {});
    await db.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS event_type VARCHAR(100);').catch(() => {});
    await db.query('ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type VARCHAR(100);').catch(() => {});

    await db.query(`
      CREATE TABLE IF NOT EXISTS reviewer_activity (
        reviewer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        reviewer_name VARCHAR(200) NOT NULL,
        reviewer_email VARCHAR(255) NOT NULL UNIQUE,
        password_hash VARCHAR(255),
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        is_available BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `).catch(() => {});

    await db.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(200) NOT NULL,
        role VARCHAR(50) NOT NULL DEFAULT 'vendor',
        is_active BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `).catch(() => {});

    // Clean old dummy credentials safely without deleting existing real user data
    console.log('🧹 Ensuring default system accounts exist...');

    // 1. Seed Admins Table (admin@gmail.com / admin123)
    console.log('1. Seeding Admin (admin@gmail.com / admin123)...');
    await db.query(`
      INSERT INTO admins (id, username, email, password_hash, full_name, is_active)
      VALUES ('00000000-0000-0000-0000-000000000001', 'admin', 'admin@gmail.com', $1, 'System Admin', TRUE)
      ON CONFLICT (email) DO UPDATE 
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [adminPasswordHash]);

    // 2. Seed Vendors Table (vendor@gmail.com / vendor123)
    console.log('2. Seeding Vendor (vendor@gmail.com / vendor123)...');
    await db.query(`
      INSERT INTO vendors (id, vendor_code, company_name, contact_person, email, phone, address, password_hash, is_active)
      VALUES ('10000000-0000-4000-8000-000000000001', 'VEN-01', 'Acme Vendor Solutions', 'Vendor Operations', 'vendor@gmail.com', '+91 98765 00001', 'Bangalore, India', $1, TRUE)
      ON CONFLICT (email) DO UPDATE 
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [vendorPasswordHash]);

    // Backfill vendor codes sequentially ONLY for vendors missing a vendor_code
    const missingVenRes = await db.query(`
      SELECT id, company_name FROM vendors WHERE vendor_code IS NULL OR vendor_code = '' ORDER BY created_at ASC, id ASC
    `).catch(() => ({ rows: [] }));

    if (missingVenRes.rows && missingVenRes.rows.length > 0) {
      let currentSeq = 1;
      for (const venRow of missingVenRes.rows) {
        let pfx = 'VEN';
        if (venRow.company_name) {
          const cleanName = venRow.company_name.trim().toUpperCase().replace(/[^A-Z0-9]/g, '');
          if (cleanName.length >= 3) pfx = cleanName.slice(0, 6);
        }
        const padStr = currentSeq < 10 ? `0${currentSeq}` : `${currentSeq}`;
        const autoCode = `${pfx}-${padStr}`;
        await db.query(`UPDATE vendors SET vendor_code = $1 WHERE id = $2`, [autoCode, venRow.id]).catch(() => {});
        currentSeq++;
      }
    }

    await db.query(`
      INSERT INTO users (id, email, password_hash, full_name, role, is_active)
      VALUES ('10000000-0000-4000-8000-000000000001', 'vendor@gmail.com', $1, 'Acme Vendor Solutions', 'vendor', TRUE)
      ON CONFLICT (email) DO UPDATE
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [vendorPasswordHash]);

    // 3. Seed Candidates Table (candidate@gmail.com / candidate123)
    console.log('3. Seeding Candidate (candidate@gmail.com / candidate123)...');
    await db.query(`
      INSERT INTO candidates (id, candidate_code, vendor_id, full_name, email, phone, password_hash, is_active)
      VALUES ('20000000-0000-4000-8000-000000000001', 'CAN-01', '10000000-0000-4000-8000-000000000001', 'Vasavi Candidate', 'candidate@gmail.com', '+91 98765 43210', $1, TRUE)
      ON CONFLICT (email) DO UPDATE 
      SET candidate_code = COALESCE(candidates.candidate_code, 'CAN-01'), password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [candidatePasswordHash]);

    // Backfill missing candidate codes sequentially (CAN-01, CAN-02, ...)
    const missingCandRes = await db.query(`
      SELECT id FROM candidates WHERE candidate_code IS NULL OR candidate_code = '' ORDER BY created_at ASC, id ASC
    `).catch(() => ({ rows: [] }));

    if (missingCandRes.rows && missingCandRes.rows.length > 0) {
      let currentSeq = 1;
      for (const candRow of missingCandRes.rows) {
        const padStr = currentSeq < 10 ? `0${currentSeq}` : `${currentSeq}`;
        const autoCode = `CAN-${padStr}`;
        await db.query(`UPDATE candidates SET candidate_code = $1 WHERE id = $2`, [autoCode, candRow.id]).catch(() => {});
        currentSeq++;
      }
    }

    // 4. Seed QC Team Table (qcteam@gmail.com / qcteam123 & qc@gmail.com / qc123456)
    console.log('4. Seeding QC Team (qcteam@gmail.com / qcteam123)...');
    await db.query(`
      INSERT INTO reviewer_activity (reviewer_id, reviewer_name, reviewer_email, password_hash, is_active, is_available)
      VALUES ('30000000-0000-4000-8000-000000000001', 'QC Team Specialist', 'qcteam@gmail.com', $1, TRUE, TRUE)
      ON CONFLICT (reviewer_email) DO UPDATE
      SET is_active = TRUE, is_available = TRUE;
    `, [qcPasswordHash]);

    await db.query(`
      INSERT INTO users (id, email, password_hash, full_name, role, is_active)
      VALUES ('30000000-0000-4000-8000-000000000001', 'qcteam@gmail.com', $1, 'QC Team Specialist', 'qc', TRUE)
      ON CONFLICT (email) DO UPDATE
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [qcPasswordHash]);

    const qcDefaultHash = await bcrypt.hash('qc123456', 10);
    await db.query(`
      INSERT INTO users (id, email, password_hash, full_name, role, is_active)
      VALUES ('30000000-0000-4000-8000-000000000002', 'qc@gmail.com', $1, 'QC Evaluator', 'qc', TRUE)
      ON CONFLICT (email) DO UPDATE
      SET password_hash = EXCLUDED.password_hash, is_active = TRUE;
    `, [qcDefaultHash]);

    console.log('🎉 Clean Database Credentials Seeding Completed Successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Seeding Error:', err.message || err);
    process.exit(1);
  }
}

seedNeonDatabase();
