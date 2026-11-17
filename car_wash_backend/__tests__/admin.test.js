require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const Payment = require('../models/paymentModel');
const Car = require('../models/carModel');

const register = async (name, email) => {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ name, email, password: 'TestPass1!' });
  return { token: res.body.token, userId: res.body.userId };
};

let admin;
let user;
const auth = (t) => ({ Authorization: `Bearer ${t}` });
const today = () => new Date().toISOString().slice(0, 10);

beforeEach(async () => {
  admin = await register('Admin', `adm_${Date.now()}@test.com`); // primer usuario = admin
  user = await register('Normal', `usr_${Date.now()}@test.com`);
});

describe('control de acceso /api/admin', () => {
  test.each([
    '/api/admin/dashboard',
    '/api/admin/reports',
    '/api/admin/users/search?email=a@b.com',
  ])('%s exige autenticación y rol admin', async (path) => {
    await request(app).get(path).expect(401);
    await request(app).get(path).set(auth(user.token)).expect(403);
  });
});

describe('GET /api/admin/dashboard', () => {
  test('devuelve métricas del día y totales', async () => {
    await Car.create({
      userId: user.userId,
      plate: 'ABC-1234',
      brand: 'Honda',
      model: 'Civic',
      washType: 'Básico',
      status: 'Completado',
      amount: 1000,
    }).catch(() => null);
    await Payment.create({
      userId: user.userId,
      plate: 'ABC-1234',
      method: 'Efectivo',
      amount: 1000,
      status: 'Pagado',
    });
    await Payment.create({
      userId: user.userId,
      plate: 'ABC-1234',
      method: 'Efectivo',
      amount: 500,
    });

    const res = await request(app).get('/api/admin/dashboard').set(auth(admin.token)).expect(200);
    expect(res.body.users).toBe(2);
    expect(res.body.payments.paid).toEqual({ count: 1, total: 1000 });
    expect(res.body.payments.pending).toEqual({ count: 1, total: 500 });
    expect(res.body.today.collected.total).toBe(1000);
    expect(res.body.today.newUsers).toBe(2);
  });
});

describe('GET /api/admin/reports', () => {
  const get = (q = '') => request(app).get(`/api/admin/reports${q}`).set(auth(admin.token));

  test('sin filtros usa el mes en curso', async () => {
    await Payment.create({
      userId: user.userId,
      plate: 'ABC-1234',
      method: 'Efectivo',
      amount: 700,
      status: 'Pagado',
    });
    const res = await get().expect(200);
    expect(res.body.summary.payments.Pagado.total).toBe(700);
    expect(res.body.movements).toHaveLength(1);
    expect(res.body.daily[0].collected).toBe(700);
  });

  test('acepta un rango válido', async () => {
    const res = await get(`?from=${today()}&to=${today()}`).expect(200);
    expect(res.body.summary).toBeDefined();
  });

  test.each([
    ['solo from', `?from=${'2025-01-01'}`],
    ['formato inválido', '?from=01/01/2025&to=02/01/2025'],
    ['fin anterior al inicio', '?from=2025-02-01&to=2025-01-01'],
    ['rango mayor a 366 días', '?from=2020-01-01&to=2025-01-01'],
    ['fecha imposible', '?from=2025-99-99&to=2025-99-99'],
  ])('rechaza %s', async (_n, q) => {
    await get(q).expect(400);
  });
});

describe('GET /api/admin/users/search', () => {
  const search = (q) => request(app).get(`/api/admin/users/search${q}`).set(auth(admin.token));

  test('encuentra por email sin distinguir mayúsculas', async () => {
    const email = `Find_${Date.now()}@test.com`;
    await register('Find', email);
    const res = await search(`?email=${encodeURIComponent(email.toUpperCase())}`).expect(200);
    expect(res.body.email).toBe(email.toLowerCase());
    expect(res.body.password).toBeUndefined();
  });

  test('404 si no existe', async () => {
    await search('?email=nadie@test.com').expect(404);
  });

  test('400 sin email o con un objeto (inyección NoSQL)', async () => {
    await search('').expect(400);
    await search('?email[$ne]=x').expect(400);
  });
});
