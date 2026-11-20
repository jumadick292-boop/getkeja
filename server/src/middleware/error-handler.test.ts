import express, { type RequestHandler } from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { errorHandler } from './error-handler.js';

function appThrowing(handler: RequestHandler) {
  const app = express();
  app.get('/boom', handler);
  app.use(errorHandler);
  return app;
}

describe('errorHandler', () => {
  it('does not leak internal error details', async () => {
    const app = appThrowing(() => {
      throw new Error('connection string postgres://admin:hunter2@db');
    });

    const response = await request(app).get('/boom');

    expect(response.status).toBe(500);
    expect(response.body).toEqual({
      success: false,
      code: 'INTERNAL_ERROR',
      message: 'Internal server error',
    });
    expect(JSON.stringify(response.body)).not.toContain('hunter2');
  });

  it('maps client errors with a status to the response', async () => {
    const app = appThrowing(() => {
      throw Object.assign(new Error('Listing is not available'), { status: 409 });
    });

    const response = await request(app).get('/boom');

    expect(response.status).toBe(409);
    expect(response.body).toEqual({
      success: false,
      code: 'CONFLICT',
      message: 'Listing is not available',
    });
  });

  it('ignores out-of-range status codes', async () => {
    const app = appThrowing(() => {
      throw Object.assign(new Error('broken'), { statusCode: 700 });
    });

    const response = await request(app).get('/boom');

    expect(response.status).toBe(500);
    expect(response.body.code).toBe('INTERNAL_ERROR');
  });

  it('uses the rate-limit error code for throttled requests', async () => {
    const app = appThrowing(() => {
      throw Object.assign(new Error('Too many requests'), { status: 429 });
    });

    const response = await request(app).get('/boom');

    expect(response.status).toBe(429);
    expect(response.body.code).toBe('RATE_LIMITED');
  });
});