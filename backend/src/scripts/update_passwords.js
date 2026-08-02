const db = require('../database/connection');
const bcrypt = require('bcryptjs');

async function updatePasswords() {
  await db.connectDB();
  const hash = await bcrypt.hash('admin123', 10);
  console.log('Generated hash for admin123:', hash);

  const adminRes = await db.query(
    'UPDATE admins SET password_hash = $1 WHERE email = $2 RETURNING email, full_name',
    [hash, 'admin@gmail.com']
  );
  console.log('Updated Admins:', adminRes.rows);

  const qcRes = await db.query(
    'UPDATE reviewer_activity SET password_hash = $1 WHERE reviewer_email = $2 RETURNING reviewer_email, reviewer_name',
    [hash, 'qcteam@gmail.com']
  );
  console.log('Updated QC Reviewers:', qcRes.rows);

  process.exit(0);
}

updatePasswords().catch((err) => {
  console.error('Error updating passwords:', err);
  process.exit(1);
});
