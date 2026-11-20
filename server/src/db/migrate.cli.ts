#!/usr/bin/env node --experimental-strip-types --import=tsx
import { runMigrations, getMigrationStatus, createMigration } from './migrate.js';
import { closeDatabase } from './pool.js';

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0];

  try {
    switch (command) {
      case 'up':
      case 'migrate': {
        const applied = await runMigrations();
        if (applied.length === 0) {
          console.log('No pending migrations');
        } else {
          console.log(`Applied ${applied.length} migration(s):`);
          for (const m of applied) {
            console.log(`  - ${m.name}`);
          }
        }
        break;
      }
      case 'status': {
        const status = await getMigrationStatus();
        console.log(`Total migrations: ${status.total}`);
        console.log(`Applied: ${status.applied.length}`);
        console.log(`Pending: ${status.pending.length}`);
        console.log(`Drift: ${status.drift ? 'YES' : 'NO'}`);
        if (status.pending.length > 0) {
          console.log('\nPending migrations:');
          for (const m of status.pending) {
            console.log(`  - ${m.filename}`);
          }
        }
        if (status.applied.length > 0) {
          console.log('\nApplied migrations:');
          for (const m of status.applied) {
            console.log(`  - ${m.name} (${m.appliedAt})`);
          }
        }
        break;
      }
      case 'create': {
        const name = args[1];
        if (!name) {
          console.error('Usage: npm run migrate create <name>');
          process.exit(1);
        }
        const path = await createMigration(name);
        console.log(`Created migration: ${path}`);
        break;
      }
      default:
        console.error('Usage: npm run migrate <up|status|create>');
        process.exit(1);
    }
  } catch (error) {
    console.error('Migration error:', error instanceof Error ? error.message : error);
    process.exit(1);
  } finally {
    await closeDatabase();
  }
}

main();