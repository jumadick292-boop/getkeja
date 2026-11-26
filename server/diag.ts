import { pool } from './src/db/pool.js';
import { resolveUserPermissions, hasPermission } from './src/modules/auth/authorization.service.js';
(async () => {
  const u = await pool.query<{id:string}>("SELECT id FROM users WHERE id IN (SELECT user_id FROM user_roles WHERE role_id='moving_company') LIMIT 1");
  if(!u.rows[0]){console.log('no moving_company user');await pool.end();return;}
  const id=u.rows[0].id;
  const r=await resolveUserPermissions(id);
  console.log('roles', [...r.roles]);
  console.log('has update_progress', await hasPermission(id,'provider.moving.update_progress'));
  console.log('has view', await hasPermission(id,'provider.moving.view'));
  await pool.end();
})().catch(e=>{console.error(e);process.exit(1)});
