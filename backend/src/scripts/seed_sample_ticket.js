require('dotenv').config();
const db = require('../database/connection');

async function seed() {
  try {
    const res = await db.query(
      `INSERT INTO qc_tickets (
        ticket_code, video_id, candidate_id, vendor_id, project_id, status, assigned_reviewer_id, assigned_reviewer_name, upload_date
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
      ON CONFLICT (ticket_code) DO NOTHING
      RETURNING *`,
      [
        'TKT-190254',
        'WEB-VID-190254',
        'c1000000-0000-0000-0000-000000000001',
        'b0000000-0000-0000-0000-000000000001',
        'PRJ-OFFICE-01',
        'pending_qc',
        'a0000000-0000-0000-0000-000000000002',
        'QC Reviewer Specialist',
      ]
    );
    console.log('✓ Ticket TKT-190254 seeded successfully:', res.rows[0] || 'Already exists');
  } catch (e) {
    console.error('Seed error:', e.message);
  } finally {
    process.exit(0);
  }
}

seed();
