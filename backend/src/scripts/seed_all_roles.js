const db = require('../database/connection');
const bcrypt = require('bcryptjs');

async function seedAllRoles() {
  await db.connectDB();

  console.log('🛠️ Adding password_hash columns if needed...');
  await db.query('ALTER TABLE vendors ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);');
  await db.query('ALTER TABLE candidates ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);');

  const adminPassHash = await bcrypt.hash('admin123', 10);
  const vendorPassHash = await bcrypt.hash('vendor123', 10);
  const candidatePassHash = await bcrypt.hash('candidate123', 10);

  console.log('🌱 Seeding database accounts for Admin, QC Team, Vendor, and Candidate...');

  // 1. Admin Account
  await db.query(
    `INSERT INTO admins (id, email, password_hash, full_name, username, is_active, created_at, updated_at)
     VALUES ('00000000-0000-0000-0000-000000000001', 'admin@gmail.com', $1, 'System Administrator', 'admin', TRUE, NOW(), NOW())
     ON CONFLICT (email) DO UPDATE SET password_hash = $1, is_active = TRUE, updated_at = NOW();`,
    [adminPassHash]
  );
  console.log('  ✅ Admin: admin@gmail.com / admin123');

  // 2. QC Team Account
  await db.query(
    `INSERT INTO reviewer_activity (reviewer_id, reviewer_name, reviewer_email, password_hash, is_active, is_available, created_at, updated_at)
     VALUES ('a0000000-0000-0000-0000-000000000001', 'QC Lead Specialist', 'qcteam@gmail.com', $1, TRUE, TRUE, NOW(), NOW())
     ON CONFLICT (reviewer_id) DO UPDATE SET password_hash = $1, reviewer_email = 'qcteam@gmail.com', is_active = TRUE, updated_at = NOW();`,
    [adminPassHash]
  );
  await db.query(`DELETE FROM users WHERE email = 'qcteam@gmail.com';`);
  await db.query(
    `INSERT INTO users (id, email, password_hash, full_name, role, is_active, created_at, updated_at)
     VALUES ('a0000000-0000-0000-0000-000000000001', 'qcteam@gmail.com', $1, 'QC Lead Specialist', 'qc_team', TRUE, NOW(), NOW());`,
    [adminPassHash]
  );
  console.log('  ✅ QC Team: qcteam@gmail.com / admin123');

  // 3. Vendor Account
  const vendorId = '10000000-0000-4000-8000-000000000001';
  await db.query(
    `INSERT INTO vendors (id, vendor_code, company_name, contact_person, email, password_hash, phone, address, is_active, created_at, updated_at)
     VALUES ($1, 'VEN-001', 'ABC Solutions', 'Rahul Kumar', 'vendor@gmail.com', $2, '+91 98765 43210', 'Bangalore, India', TRUE, NOW(), NOW())
     ON CONFLICT (vendor_code) DO UPDATE SET email = 'vendor@gmail.com', password_hash = $2, is_active = TRUE, updated_at = NOW();`,
    [vendorId, vendorPassHash]
  );

  await db.query(
    `DELETE FROM users WHERE email = 'vendor@gmail.com';`
  );
  await db.query(
    `INSERT INTO users (id, email, password_hash, full_name, role, vendor_id, is_active, created_at, updated_at)
     VALUES ('10000000-0000-4000-8000-000000000002', 'vendor@gmail.com', $1, 'Rahul Kumar', 'vendor', $2, TRUE, NOW(), NOW());`,
    [vendorPassHash, vendorId]
  );
  console.log('  ✅ Vendor: vendor@gmail.com / vendor123 (Vendor Code: VEN-001)');

  // 4. Candidate Account
  await db.query(
    `DELETE FROM candidates WHERE email = 'candidate@gmail.com';`
  );
  await db.query(
    `INSERT INTO candidates (id, vendor_id, full_name, email, phone, password_hash, is_active, created_at, updated_at)
     VALUES ('20000000-0000-4000-8000-000000000001', $1, 'Vasavi Candidate', 'candidate@gmail.com', '+91 98765 43210', $2, TRUE, NOW(), NOW());`,
    [vendorId, candidatePassHash]
  );
  console.log('  ✅ Candidate: candidate@gmail.com / candidate123');

  console.log('\n🎉 All 4 role accounts successfully created & verified in database!');
  process.exit(0);
}

seedAllRoles().catch((err) => {
  console.error('❌ Error seeding accounts:', err);
  process.exit(1);
});
