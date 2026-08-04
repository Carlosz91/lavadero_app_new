require('./helpers/setup');
const request = require('supertest');
const app = require('../server');

describe('GET /health', () => {
  test('returns health status', async () => {
    const res = await request(app)
      .get('/health')
      .expect(200);

    expect(res.body).toHaveProperty('status');
    expect(res.body).toHaveProperty('message');
    expect(res.body).toHaveProperty('timestamp');
    expect(res.body).toHaveProperty('uptime');
    expect(res.body).toHaveProperty('mongodb');
    expect(res.body.status).toBe('OK');
  });
});

describe('GET /api/routes-check', () => {
  test('is removed for security (returns 404)', async () => {
    const res = await request(app)
      .get('/api/routes-check')
      .expect(404);

    expect(res.body.error).toBe('Ruta no encontrada');
  });
});

describe('GET /nonexistent', () => {
  test('returns 404 for unknown routes', async () => {
    const res = await request(app)
      .get('/nonexistent')
      .expect(404);

    expect(res.body.error).toBe('Ruta no encontrada');
  });
});

describe('X-Request-Id header', () => {
  test('is set on response', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-request-id']).toBeDefined();
  });
});
