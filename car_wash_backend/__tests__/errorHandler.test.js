require('./helpers/setup');
const request = require('supertest');
const app = require('../server');

describe('Manejo de JSON inválido', () => {
  test('responde 400 con un mensaje funcional en lugar de 500', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .set('Content-Type', 'application/json')
      .send('{"email": "incompleto"');

    expect(res.status).toBe(400);
    expect(res.body.code).toBe('INVALID_JSON');
    expect(res.body.error).toContain('JSON');
  });
});
