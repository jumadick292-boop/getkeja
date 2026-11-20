import type { Session } from '../modules/auth/auth.types.js';

declare global {
  namespace Express {
    interface Request {
      user?: import('../modules/auth/auth.types.js').AuthUser;
      session?: Session;
    }
  }
}

export {};