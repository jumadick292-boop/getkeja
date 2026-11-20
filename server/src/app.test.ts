import { Writable } from 'node:stream';
import { pino } from 'pino';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { createApp } from './app.js';

const app = createApp();

describe('GET /health', () => {
  it('reports the service as healthy', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
    expect(response.headers['content-type']).toMatch(/application\/json/);
    expect(response.headers['x-powered-by']).toBeUndefined();
  });
});

describe('unknown routes', () => {
  it('returns a JSON 404 payload', async () => {
    const response = await request(app).get('/does-not-exist');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({
      success: false,
      code: 'NOT_FOUND',
      message: 'Cannot GET /does-not-exist',
    });
  });
});

describe('request body handling', () => {
  it('rejects malformed JSON with a 400', async () => {
    const response = await request(app)
      .post('/anything')
      .set('content-type', 'application/json')
      .send('{"broken":');

    expect(response.status).toBe(400);
    expect(response.body.code).toBe('INVALID_JSON');
  });

  it('rejects bodies above the configured limit with a 413', async () => {
    const payload = JSON.stringify({ data: 'x'.repeat(1_100_000) });

    const response = await request(app)
      .post('/anything')
      .set('content-type', 'application/json')
      .send(payload);

    expect(response.status).toBe(413);
    expect(response.body.code).toBe('PAYLOAD_TOO_LARGE');
  });
});

describe('cross-origin protections', () => {
  it('allows configured origins and rejects unknown origins', async () => {
    const allowed = await request(app)
      .get('/health')
      .set('Origin', 'http://localhost:3000');
    expect(allowed.status).toBe(200);
    expect(allowed.headers['access-control-allow-origin']).toBe('http://localhost:3000');

    const denied = await request(app)
      .get('/health')
      .set('Origin', 'https://untrusted.example');
    expect(denied.status).toBe(403);
    expect(denied.body.code).toBe('FORBIDDEN');
  });

  it('requires a trusted origin for cookie-authenticated mutations', async () => {
    const response = await request(app)
      .post('/api/v1/auth/logout')
      .set('Cookie', 'getkeja_refresh=test-token')
      .send({});

    expect(response.status).toBe(403);
  });
});

describe('readiness checks', () => {
  it('returns 503 when a dependency check fails', async () => {
    const notReadyApp = createApp({
      readinessCheck: async () => {
        throw new Error('dependency unavailable');
      },
    });

    const response = await request(notReadyApp).get('/ready');

    expect(response.status).toBe(503);
    expect(response.body).toEqual({ status: 'not_ready' });
  });
});

describe('HTTP request logging', () => {
  it('logs request metadata without query strings or authorization headers', async () => {
    const records: string[] = [];
    const destination = new Writable({
      write(chunk, _encoding, callback) {
        records.push(chunk.toString());
        callback();
      },
    });
    const loggingApp = createApp({
      logger: pino({ level: 'info' }, destination),
    });

    await request(loggingApp)
      .get('/health?access_token=secret-token')
      .set('Authorization', 'Bearer secret-token');

    expect(records).toHaveLength(1);
    const line = records[0];
    if (line === undefined) throw new Error('Expected an HTTP request log');
    const log = JSON.parse(line);
    expect(log.req).toMatchObject({ method: 'GET', url: '/health' });
    expect(log.res.statusCode).toBe(200);
    expect(log.responseTime).toEqual(expect.any(Number));
    expect(line).not.toContain('secret-token');
  });
});