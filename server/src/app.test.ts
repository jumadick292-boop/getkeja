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
      error: {
        code: 'NOT_FOUND',
        message: 'Cannot GET /does-not-exist',
      },
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
    expect(response.body.error.code).toBe('INVALID_JSON');
  });

  it('rejects bodies above the configured limit with a 413', async () => {
    const payload = JSON.stringify({ data: 'x'.repeat(1_100_000) });

    const response = await request(app)
      .post('/anything')
      .set('content-type', 'application/json')
      .send(payload);

    expect(response.status).toBe(413);
    expect(response.body.error.code).toBe('PAYLOAD_TOO_LARGE');
  });
});
