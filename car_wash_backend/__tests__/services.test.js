require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const User = require('../models/userModel');
const Car = require('../models/carModel');
const Payment = require('../models/paymentModel');
const carService = require('../services/carService');
const paymentService = require('../services/paymentService');

let n = 0;
const register = async (name = 'Svc User') => {
  const email = `svc_${Date.now()}_${n++}@test.com`;
  const res = await request(app)
    .post('/api/auth/register')
    .send({ name, email, password: 'TestPass1!' });
  return { email, token: res.body.token, userId: res.body.userId };
};

describe('POST /api/auth/google', () => {
  const realFetch = global.fetch;
  const prevClient = process.env.GOOGLE_CLIENT_ID;
  const google = (payload, ok = true) => {
    global.fetch = jest.fn().mockResolvedValue({ ok, json: async () => payload });
  };
  const login = (idToken = 'tok') => request(app).post('/api/auth/google').send({ idToken });
  const idPayload = (extra = {}) => ({
    sub: 'g-123',
    email: `google_${Date.now()}@test.com`,
    name: 'Google User',
    aud: 'my-client',
    email_verified: 'true',
    ...extra,
  });

  beforeEach(() => {
    process.env.GOOGLE_CLIENT_ID = 'my-client';
  });
  afterEach(() => {
    global.fetch = realFetch;
    process.env.GOOGLE_CLIENT_ID = prevClient;
  });

  test('crea el usuario con un token válido y devuelve tokens', async () => {
    google(idPayload());
    const res = await login().expect(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.refreshToken).toBeDefined();
    expect(await User.countDocuments()).toBe(1);
  });

  test('el idToken viaja codificado en la URL', async () => {
    google(idPayload());
    await login('a b&c=d').expect(200);
    expect(global.fetch.mock.calls[0][0]).toContain('id_token=a%20b%26c%3Dd');
  });

  test('rechaza un token con correo NO verificado (evita tomar cuentas ajenas)', async () => {
    const victim = await register();
    google(idPayload({ email: victim.email, email_verified: 'false' }));
    await login().expect(401);
    expect((await User.findOne({ email: victim.email })).googleId).toBeNull();
  });

  test('vincula una cuenta existente solo con correo verificado', async () => {
    const existing = await register();
    google(idPayload({ email: existing.email, email_verified: true }));
    await login().expect(200);
    expect((await User.findOne({ email: existing.email })).googleId).toBe('g-123');
  });

  test('rechaza audiencia distinta, token inválido y token faltante', async () => {
    google(idPayload({ aud: 'otra-app' }));
    await login().expect(401);
    google({ error: 'invalid_token' }, false);
    await login().expect(401);
    await request(app).post('/api/auth/google').send({}).expect(400);
  });

  test('en producción sin GOOGLE_CLIENT_ID responde error de configuración', async () => {
    delete process.env.GOOGLE_CLIENT_ID;
    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      const { verifyIdToken } = require('../services/googleAuthService');
      google(idPayload());
      await expect(verifyIdToken('tok')).rejects.toMatchObject({ code: 'SERVER_CONFIG' });
    } finally {
      process.env.NODE_ENV = prev;
    }
  });
});

describe('carService', () => {
  const mkCar = async (userId, status = 'Pendiente') =>
    Car.create({
      userId,
      plate: `SVC-${n++}`,
      brand: 'X',
      model: 'Y',
      washType: 'Básico',
      amount: 5000,
      status,
    });

  test('changeStatus valida las transiciones', async () => {
    const { userId } = await register();
    const car = await mkCar(userId);
    await expect(carService.changeStatus(car._id, 'Completado')).rejects.toMatchObject({
      statusCode: 400,
    });
    const updated = await carService.changeStatus(car._id, 'En Progreso');
    expect(updated.status).toBe('En Progreso');
  });

  test('changeStatus de un auto inexistente => 404', async () => {
    await expect(
      carService.changeStatus('64b7f0f0f0f0f0f0f0f0f0f0', 'En Progreso')
    ).rejects.toMatchObject({
      statusCode: 404,
    });
  });

  test('closeCar crea el pago pendiente con el monto del auto', async () => {
    const { userId } = await register();
    const car = await mkCar(userId, 'En Progreso');
    const { car: closed, payment } = await carService.closeCar(car._id);
    expect(closed.status).toBe('Completado');
    expect(payment).toMatchObject({ status: 'Pendiente', amount: 5000 });
    expect(String(payment.userId)).toBe(String(userId));
  });

  test('closeCar revierte el pago si falla el guardado del auto', async () => {
    const { userId } = await register();
    const car = await mkCar(userId, 'En Progreso');
    const spy = jest.spyOn(Car.prototype, 'save').mockRejectedValueOnce(new Error('db caída'));
    await expect(carService.closeCar(car._id)).rejects.toThrow('db caída');
    spy.mockRestore();
    expect(await Payment.countDocuments({ carId: car._id })).toBe(0);
  });

  test('closeCar solo cierra vehículos En Progreso', async () => {
    const { userId } = await register();
    const car = await mkCar(userId, 'Pendiente');
    await expect(carService.closeCar(car._id)).rejects.toMatchObject({ statusCode: 400 });
  });
});

describe('paymentService', () => {
  test('updatePayment rechaza a quien no es personal', async () => {
    const { userId } = await register();
    const p = await Payment.create({ userId, plate: 'PS-1', method: 'Stripe', amount: 100 });
    await expect(
      paymentService.updatePayment({ id: userId, role: 'user' }, p._id, { status: 'Pagado' })
    ).rejects.toMatchObject({ statusCode: 403 });
  });

  test('updatePayment valida el método y actualiza para personal', async () => {
    const { userId } = await register();
    const p = await Payment.create({ userId, plate: 'PS-2', method: 'Otro', amount: 100 });
    const staff = { id: userId, role: 'staff' };
    await expect(
      paymentService.updatePayment(staff, p._id, { status: 'Pagado', method: 'Bitcoin' })
    ).rejects.toMatchObject({ statusCode: 400 });
    const updated = await paymentService.updatePayment(staff, p._id, {
      status: 'Pagado',
      method: 'Efectivo',
    });
    expect(updated).toMatchObject({ status: 'Pagado', method: 'Efectivo' });
  });

  test('updatePayment de un pago inexistente => 404', async () => {
    await expect(
      paymentService.updatePayment({ id: 'x', role: 'admin' }, '64b7f0f0f0f0f0f0f0f0f0f0', {
        status: 'Pagado',
      })
    ).rejects.toMatchObject({ statusCode: 404 });
  });
});

describe('recuperación de contraseña (servicio)', () => {
  const mailer = require('../utils/mailer');
  const { requestReset, resetPassword } = require('../services/passwordResetService');

  test('requestReset envía el código y resetPassword lo consume una sola vez', async () => {
    const u = await register();
    const spy = jest.spyOn(mailer, 'sendMail').mockResolvedValue(true);
    await requestReset(u.email);
    expect(spy).toHaveBeenCalledTimes(1);
    const code = spy.mock.calls[0][2].match(/Código: (\w+)/)[1];
    spy.mockRestore();

    await resetPassword(code, 'NuevaClave1!');
    await expect(resetPassword(code, 'OtraClave1!')).rejects.toMatchObject({ statusCode: 400 });
    await request(app)
      .post('/api/auth/login')
      .send({ email: u.email, password: 'NuevaClave1!' })
      .expect(200);
  });

  test('requestReset no hace nada (ni falla) con email inexistente', async () => {
    const spy = jest.spyOn(mailer, 'sendMail').mockResolvedValue(true);
    await expect(requestReset('nadie@test.com')).resolves.toBeUndefined();
    expect(spy).not.toHaveBeenCalled();
    spy.mockRestore();
  });
});
