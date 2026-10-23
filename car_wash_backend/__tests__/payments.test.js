require('./helpers/setup');
const request = require('supertest');
const app = require('../server');

const register = async (name, email) => {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ name, email, password: 'TestPass1!' });
  return { token: res.body.token, userId: res.body.userId, role: res.body.user?.role };
};

const createCar = async (token, plate) =>
  request(app)
    .post('/api/cars/registercar')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', `pay-${Date.now()}-car-${Math.random()}`)
    .send({ plate, brand: 'Honda', model: 'Civic', washType: 'Básico' });

const closeCar = async (token, carId) =>
  request(app)
    .put(`/api/cars/close-car/${carId}`)
    .set('Authorization', `Bearer ${token}`);

const startCar = async (token, carId) =>
  request(app)
    .put(`/api/cars/update-status/${carId}`)
    .set('Authorization', `Bearer ${token}`)
    .send({ status: 'En Progreso' });

describe('POST /api/payments', () => {
  let tokenAdmin;
  let tokenUser;

  beforeEach(async () => {
    const admin = await register('PayAdmin', `pay_admin_${Date.now()}@test.com`);
    tokenAdmin = admin.token;
    const user = await register('PayUser', `pay_user_${Date.now()}@test.com`);
    tokenUser = user.token;
  });

  test('creates a payment (admin)', async () => {
    const res = await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .set('Idempotency-Key', `pay-${Date.now()}-1`)
      .send({ plate: 'XYZ-5678', method: 'Tarjeta', amount: 200 })
      .expect(201);

    expect(res.body.status).toBe('Pendiente');
  });

  test('rejects without auth', async () => {
    await request(app)
      .post('/api/payments')
      .send({ plate: 'XYZ-5678', method: 'Tarjeta', amount: 200 })
      .expect(401);
  });

  test('rejects non-admin user', async () => {
    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${tokenUser}`)
      .set('Idempotency-Key', `pay-${Date.now()}-2`)
      .send({ plate: 'XYZ-5678', method: 'Tarjeta', amount: 200 })
      .expect(403);
  });

  test('rejects invalid method', async () => {
    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .set('Idempotency-Key', `pay-${Date.now()}-3`)
      .send({ plate: 'XYZ-5678', method: 'Cripto', amount: 200 })
      .expect(400);
  });

  test('rejects missing fields', async () => {
    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .set('Idempotency-Key', `pay-${Date.now()}-4`)
      .send({ plate: 'XYZ-5678' })
      .expect(400);
  });
});

describe('GET /api/payments', () => {
  let tokenUser;

  beforeEach(async () => {
    const admin = await register('PayGetAdmin', `pay_get_adm_${Date.now()}@test.com`);
    const user = await register('PayGetUser', `pay_get_${Date.now()}@test.com`);
    tokenUser = user.token;

    const carRes = await createCar(tokenUser, 'ABC-1234');
    await startCar(admin.token, carRes.body.car._id);
    await closeCar(admin.token, carRes.body.car._id);
  });

  test('gets authenticated user payments with pagination', async () => {
    const res = await request(app)
      .get('/api/payments')
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(1);
    expect(res.body.pagination).toMatchObject({ page: 1, limit: 20, total: 1 });
    expect(res.body.data[0].amount).toBe(50000);
  });
});

describe('GET /api/payments/user/:userId', () => {
  let tokenUser;
  let userId;

  beforeEach(async () => {
    const admin = await register('PayUidAdmin', `pay_uid_adm_${Date.now()}@test.com`);
    const user = await register('PayUidUser', `pay_uid_${Date.now()}@test.com`);
    tokenUser = user.token;
    userId = user.userId;

    const carRes = await createCar(tokenUser, 'ABC-1234');
    await startCar(admin.token, carRes.body.car._id);
    await closeCar(admin.token, carRes.body.car._id);
  });

  test('gets payments by userId (self)', async () => {
    const res = await request(app)
      .get(`/api/payments/user/${userId}`)
      .set('Authorization', `Bearer ${tokenUser}`)
      .expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body.pagination.total).toBe(1);
  });

  test('rejects access to other user payments without admin', async () => {
    const other = await register('PayOther', `pay_other_${Date.now()}@test.com`);

    await request(app)
      .get(`/api/payments/user/${userId}`)
      .set('Authorization', `Bearer ${other.token}`)
      .expect(403);
  });
});

describe('PUT /api/payments/:id', () => {
  let tokenAdmin;
  let tokenUser1;
  let tokenUser2;
  let paymentId;

  beforeEach(async () => {
    const admin = await register('PayPutAdmin', `pay_put_adm_${Date.now()}@test.com`);
    const user1 = await register('PayPutUser1', `pay_put_1_${Date.now()}@test.com`);
    const user2 = await register('PayPutUser2', `pay_put_2_${Date.now()}@test.com`);
    tokenAdmin = admin.token;
    tokenUser1 = user1.token;
    tokenUser2 = user2.token;

    const carRes = await createCar(tokenUser1, 'ABC-1234');
    await startCar(tokenAdmin, carRes.body.car._id);
    await closeCar(tokenAdmin, carRes.body.car._id);

    const payRes = await request(app)
      .get('/api/payments')
      .set('Authorization', `Bearer ${tokenUser1}`)
      .expect(200);
    paymentId = payRes.body.data[0]._id;
  });

  test('admin/staff can update payment status', async () => {
    const res = await request(app)
      .put(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ status: 'Pagado' })
      .expect(200);

    expect(res.body.status).toBe('Pagado');
  });

  test('rejects owner updating own payment (solo staff)', async () => {
    await request(app)
      .put(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${tokenUser1}`)
      .send({ status: 'Pagado' })
      .expect(403);
  });

  test('rejects updating another user payment', async () => {
    await request(app)
      .put(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${tokenUser2}`)
      .send({ status: 'Pagado' })
      .expect(403);
  });

  test('rejects invalid status', async () => {
    await request(app)
      .put(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ status: 'Invalido' })
      .expect(400);
  });

  test('rejects without auth', async () => {
    await request(app)
      .put(`/api/payments/${paymentId}`)
      .send({ status: 'Pagado' })
      .expect(401);
  });
});
