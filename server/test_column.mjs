import { pool } from './src/db/pool.js';
const r = await pool.query(`SELECT column_name FROM information_schema.columns WHERE table_name = 'rental_proposals' ORDER BY ordinal_position`);
console.log(r.rows.map(row => row.column_name).join(', '));
await pool.end();
