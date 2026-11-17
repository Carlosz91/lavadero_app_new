require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const Idempotency = require('../models/idempotencyModel');

let n = 0;
const newUser = async () => {
  const res = await request(app)
    .post('/api/auth/register')
    .send({
      name: 'Idem User',
      email: `idem_${Date.now()}_${n++}@test.com`,
      password: 'TestPass1!',
    });
  return { token: res.body.token, userId: res.body.userId };
};

const post = (token, key, body) =>
  request(app)
    .post('/api/cars/registercar')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', key)
    .send(body);

const car = (plate) => ({ plate, brand: 'Honda', model: 'Civic', washType: 'Básico' });

describe('Idempotency-Key', () => {
  test('la misma petición con la misma clave devuelve la respuesta guardada', async () => {
    const u = await newUser();
    const a = await post(u.token, 'k-same', car('IDM-1')).expect(201);
    const b = await post(u.token, 'k-same', car('IDM-1')).expect(201);
    expect(b.body.car._id).toBe(a.body.car._id);
  });

  test('otro usuario NO recibe la respuesta guardada de una clave ajena', async () => {
    const [a, b] = await Promise.all([newUser(), newUser()]);
    const ra = await post(a.token, 'k-shared', car('IDM-A')).expect(201);
    const rb = await post(b.token, 'k-shared', car('IDM-B')).expect(201);
    expect(rb.body.car._id).not.toBe(ra.body.car._id);
    expect(rb.body.car.userId).toBe(b.userId);
  });

  test('misma clave con otro cuerpo => 422', async () => {
    const u = await newUser();
    await post(u.token, 'k-body', car('IDM-1')).expect(201);
    const res = await post(u.token, 'k-body', car('IDM-2')).expect(422);
    expect(res.body.code).toBe('IDEMPOTENCY_KEY_REUSED');
  });

  test('un error libera la clave: se puede reintentar corregida', async () => {
    const u = await newUser();
    await post(u.token, 'k-fix', { ...car('IDM-1'), washType: 'Inexistente' }).expect(400);
    expect(await Idempotency.countDocuments({ key: 'k-fix' })).toBe(0);
    await post(u.token, 'k-fix', car('IDM-1')).expect(201);
  });

  test('peticiones simultáneas con la misma clave crean un solo recurso', async () => {
    const u = await newUser();
    const rs = await Promise.all([1, 2, 3, 4].map(() => post(u.token, 'k-race', car('IDM-R'))));
    const created = rs.filter((r) => r.status === 201);
    expect(created.length).toBeGreaterThanOrEqual(1);
    expect(new Set(created.map((r) => r.body.car._id)).size).toBe(1);
    rs.filter((r) => r.status !== 201).forEach((r) => expect(r.status).toBe(409));
  });

  test('exige el header y limita su largo', async () => {
    const u = await newUser();
    await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${u.token}`)
      .send(car('IDM-1'))
      .expect(400);
    await post(u.token, 'x'.repeat(129), car('IDM-1')).expect(400);
  });
});
