require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const User = require('../models/userModel');
const Car = require('../models/carModel');
const Payment = require('../models/paymentModel');
const { validateEnv, assertEnv } = require('../config/env');
const { reconcileOnce } = require('../services/paymentReconciler');
const constants = require('../config/constants');

let n = 0;
const register = async (name = 'Hard User') => {
  const email = `hard_${Date.now()}_${n++}@test.com`;
  const res = await request(app)
    .post('/api/auth/register')
    .send({ name, email, password: 'TestPass1!' });
  return { email, token: res.body.token, userId: res.body.userId };
};

describe('validación de entorno', () => {
  const good = {
    NODE_ENV: 'production',
    MONGO_URI: 'mongodb://x/y',
    JWT_SECRET: 'a'.repeat(40),
    JWT_REFRESH_SECRET: 'b'.repeat(40),
    ALLOWED_ORIGINS: 'https://app.example.org',
    GOOGLE_CLIENT_ID: 'id',
    STRIPE_SECRET_KEY: 'sk',
    STRIPE_WEBHOOK_SECRET: 'wh',
  };

  test('configuración correcta no produce errores', () => {
    expect(validateEnv(good).errors).toEqual([]);
  });

  test.each([
    ['sin MONGO_URI', { MONGO_URI: undefined }],
    ['JWT_SECRET corto', { JWT_SECRET: 'corto' }],
    ['JWT_SECRET de ejemplo', { JWT_SECRET: 'change-this-to-a-random-secret-in-production-xx' }],
    ['refresh igual al access', { JWT_REFRESH_SECRET: 'a'.repeat(40) }],
    ['sin refresh secret', { JWT_REFRESH_SECRET: undefined }],
    ['Stripe a medias', { STRIPE_WEBHOOK_SECRET: undefined }],
  ])('producción rechaza: %s', (_n, override) => {
    expect(validateEnv({ ...good, ...override }).errors.length).toBeGreaterThan(0);
  });

  test('assertEnv lanza con la lista de problemas y no actúa en test', () => {
    expect(() => assertEnv({ ...good, MONGO_URI: undefined })).toThrow(/MONGO_URI/);
    expect(() => assertEnv({ NODE_ENV: 'test' })).not.toThrow();
  });

  test('advierte (sin fallar) de RATE_LIMIT_MAX en producción', () => {
    const { errors, warnings } = validateEnv({ ...good, RATE_LIMIT_MAX: '1000' });
    expect(errors).toEqual([]);
    expect(warnings.join()).toMatch(/RATE_LIMIT_MAX/);
  });
});

describe('catálogos únicos', () => {
  test('los enums de los modelos salen de constants', () => {
    expect(Car.schema.path('status').enumValues).toEqual(constants.CAR_STATUSES);
    expect(Car.schema.path('washType').enumValues).toEqual(constants.WASH_TYPES);
    expect(Payment.schema.path('method').enumValues).toEqual(constants.PAYMENT_METHODS);
    expect(Payment.schema.path('status').enumValues).toEqual(constants.PAYMENT_STATUSES);
  });
});

describe('bloqueo progresivo de cuenta', () => {
  const failLogin = (email) =>
    request(app).post('/api/auth/login').send({ email, password: 'Incorrecta1!' });

  test('el primer bloqueo dura 5 min, el siguiente 15, y un login exitoso reinicia', async () => {
    await register(); // primer usuario (admin)
    const u = await register();

    for (let i = 0; i < 5; i += 1) await failLogin(u.email);
    let doc = await User.findOne({ email: u.email });
    expect(Math.round((doc.lockUntil - Date.now()) / 60000)).toBe(5);
    expect(doc.lockCount).toBe(1);

    // Simula que el bloqueo venció y se insiste otra vez
    await User.updateOne(
      { email: u.email },
      { lockUntil: new Date(Date.now() - 1000), loginAttempts: 0 }
    );
    for (let i = 0; i < 5; i += 1) await failLogin(u.email);
    doc = await User.findOne({ email: u.email });
    expect(Math.round((doc.lockUntil - Date.now()) / 60000)).toBe(15);

    // Login correcto tras vencer: reinicia contadores
    await User.updateOne({ email: u.email }, { lockUntil: new Date(Date.now() - 1000) });
    await request(app)
      .post('/api/auth/login')
      .send({ email: u.email, password: 'TestPass1!' })
      .expect(200);
    doc = await User.findOne({ email: u.email });
    expect(doc.lockCount).toBe(0);
    expect(doc.loginAttempts).toBe(0);
  });

  test('una cuenta bloqueada responde 403 ACCOUNT_LOCKED', async () => {
    await register();
    const u = await register();
    for (let i = 0; i < 5; i += 1) await failLogin(u.email);
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: u.email, password: 'TestPass1!' })
      .expect(403);
    expect(res.body.code).toBe('ACCOUNT_LOCKED');
  });
});

describe('POST /api/payments: dueño del pago', () => {
  const create = (token, body) =>
    request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `own-${Date.now()}-${Math.random()}`)
      .send({ plate: 'OWN-001', method: 'Efectivo', amount: 1000, ...body });

  test('con userId explícito el pago queda a nombre del cliente', async () => {
    const admin = await register();
    const client = await register();
    const res = await create(admin.token, { userId: client.userId }).expect(201);
    expect(res.body.userId).toBe(client.userId);
  });

  test('con carId toma el dueño del auto', async () => {
    const admin = await register();
    const client = await register();
    const car = await Car.create({
      userId: client.userId,
      plate: 'OWN-002',
      brand: 'X',
      model: 'Y',
      washType: 'Básico',
      amount: 1,
    });
    const res = await create(admin.token, { carId: car._id.toString() }).expect(201);
    expect(res.body.userId).toBe(client.userId);
  });

  test('usuario o auto inexistente => 404; ids inválidos => 400', async () => {
    const admin = await register();
    await create(admin.token, { userId: '64b7f0f0f0f0f0f0f0f0f0f0' }).expect(404);
    await create(admin.token, { carId: '64b7f0f0f0f0f0f0f0f0f0f0' }).expect(404);
    await create(admin.token, { userId: 'no-es-id' }).expect(400);
  });

  test('sin userId ni carId se mantiene el comportamiento anterior', async () => {
    const admin = await register();
    const res = await create(admin.token, {}).expect(201);
    expect(res.body.userId).toBe(admin.userId);
  });
});

describe('conciliación de pagos con Stripe', () => {
  const old = () => new Date(Date.now() - 60 * 60 * 1000);
  const mkPayment = async (extra = {}) => {
    const u = await register();
    const p = await Payment.create({
      userId: u.userId,
      plate: 'REC-001',
      method: 'Stripe',
      amount: 5000,
      checkoutSessionId: 'cs_x',
      ...extra,
    });
    // timestamps: forzar antigüedad para pasar el umbral
    await Payment.collection.updateOne({ _id: p._id }, { $set: { updatedAt: old() } });
    return p;
  };
  const stripeWith = (session) => () => ({
    checkout: { sessions: { retrieve: jest.fn().mockResolvedValue(session) } },
  });

  test('marca como Pagado lo cobrado cuyo webhook no llegó', async () => {
    const p = await mkPayment();
    const r = await reconcileOnce(stripeWith({ payment_status: 'paid', status: 'complete' }));
    expect(r).toMatchObject({ checked: 1, paid: 1 });
    expect((await Payment.findById(p._id)).status).toBe('Pagado');
  });

  test('libera el checkout vencido sin cobro', async () => {
    const p = await mkPayment();
    const r = await reconcileOnce(stripeWith({ payment_status: 'unpaid', status: 'expired' }));
    expect(r.expired).toBe(1);
    expect((await Payment.findById(p._id)).checkoutSessionId).toBeNull();
  });

  test('ignora pagos recientes (dan tiempo al webhook) y checkouts aún abiertos', async () => {
    const recent = await mkPayment();
    await Payment.collection.updateOne({ _id: recent._id }, { $set: { updatedAt: new Date() } });
    expect((await reconcileOnce(stripeWith({ payment_status: 'paid' }))).checked).toBe(0);

    const open = await mkPayment();
    const r = await reconcileOnce(stripeWith({ payment_status: 'unpaid', status: 'open' }));
    expect(r.paid + r.expired).toBe(0);
    expect((await Payment.findById(open._id)).status).toBe('Pendiente');
  });

  test('un fallo de Stripe en un pago no detiene la conciliación', async () => {
    await mkPayment();
    const failing = () => ({
      checkout: { sessions: { retrieve: jest.fn().mockRejectedValue(new Error('net')) } },
    });
    const r = await reconcileOnce(failing);
    expect(r).toMatchObject({ checked: 1, failed: 1, paid: 0 });
  });
});
