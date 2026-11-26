import { createApp } from './src/app.js';
import request from 'supertest';
import { pool } from './src/db/pool.js';

const app = createApp({ nodeEnv: 'test' });

async function registerAndLogin(role) {
  const email = `test${Date.now()}${Math.floor(Math.random() * 1000000)}@example.com`;
  const reg = await request(app).post('/api/auth/register/email').send({
    firstName: 'Test', lastName: role, email, password: 'password123', role, termsAccepted: true,
  });
  console.log('Register status:', reg.status);
  if (reg.status !== 201) {
    console.log('Register body:', JSON.stringify(reg.body, null, 2));
    return null;
  }
  await pool.query(`UPDATE user_login_identities SET verified_at = NOW() WHERE identifier = $1 AND provider = 'email'`, [email]);
  await pool.query(`UPDATE users SET email_verified = TRUE, account_status = 'active', mfa_enrollment_required = FALSE WHERE email = $1`, [email]);
  const user = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  const userId = user.rows[0].id;
  await pool.query(`INSERT INTO user_roles (user_id, role_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`, [userId, role]);
  const login = await request(app).post('/api/auth/login/email').send({ email, password: 'password123' });
  console.log('Login status:', login.status);
  return { id: userId, token: login.headers['x-access-token'] };
}

const landlord = await registerAndLogin('landlord');
if (!landlord) process.exit(1);
const seeker = await registerAndLogin('house_seeker');
if (!seeker) process.exit(1);

const prop = await pool.query(
  `INSERT INTO properties (organisation_id, title, description, property_type, status, address, city, county, country, total_units, created_by, published_at)
   VALUES (NULL, 'Test Property', 'Test', 'apartment', 'published', '1 Test St', 'Nairobi', 'Nairobi', 'KE', 3, $1, NOW()) RETURNING id`,
  [landlord.id],
);
const propertyId = prop.rows[0].id;
const unit = await pool.query(
  `INSERT INTO units (property_id, unit_number, unit_type, bedrooms, bathrooms, rent_amount, deposit_amount, status, created_by)
   VALUES ($1, 'A-101', 'one_bedroom', 1, 1, 45000, 90000, 'vacant', $2) RETURNING id`,
  [propertyId, landlord.id],
);
const unitId = unit.rows[0].id;

const appRes = await request(app).post('/api/v1/rental-applications/applications')
  .set('Authorization', `Bearer ${seeker.token}`)
  .send({
    propertyId, unitId,
    preferredStartDate: '2026-12-01', preferredEndDate: '2027-12-01',
    proposedRentAmount: 45000,
  });
console.log('App status:', appRes.status);
if (appRes.status >= 400) {
  console.log('App error:', JSON.stringify(appRes.body, null, 2));
  process.exit(1);
}
const appId = appRes.body.id;

const propRes = await request(app).post('/api/v1/landlord/rental-proposals')
  .set('Authorization', `Bearer ${landlord.token}`)
  .send({
    propertyId, unitId, prospectiveRenterId: seeker.id,
    rentalApplicationId: appId,
    type: 'new_tenancy',
    proposedRentAmount: 45000, proposedDepositAmount: 90000,
    proposedStartDate: '2026-12-01',
    expiresAt: '2026-12-31T23:59:59Z',
  });
console.log('Proposal status:', propRes.status);
if (propRes.status >= 500) {
  console.log('Error body:', JSON.stringify(propRes.body, null, 2));
} else {
  console.log('Proposal body:', JSON.stringify(propRes.body, null, 2));
}

await pool.end();
