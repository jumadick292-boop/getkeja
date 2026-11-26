import { pool } from './src/db/pool.js';
const sql = `ALTER TABLE rental_proposals
    ADD COLUMN IF NOT EXISTS rental_application_id UUID REFERENCES rental_applications(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_rental_proposals_rental_application_id ON rental_proposals (rental_application_id);`;
try {
  await pool.query(sql);
  console.log('Migration 097 applied successfully');
} catch (err) {
  console.error('Migration 097 failed:', err.message);
  process.exit(1);
} finally {
  await pool.end();
}
