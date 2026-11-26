import * as repository from './location-sharing.repository.js';

let timer: NodeJS.Timeout | undefined;

export function startLocationSharingCleanup() {
  if (timer) return;
  const run = () => void repository.cleanupExpired().catch(() => undefined);
  run();
  timer = setInterval(run, 60_000);
  timer.unref();
}

export function stopLocationSharingCleanup() {
  if (!timer) return;
  clearInterval(timer);
  timer = undefined;
}
