require('./helpers/setup');
const request = require('supertest');
const app = require('../server');

describe('POST /api/payments', () => {
  let token;

  beforeEach(async () => {
    const email = `pay_reg_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Pay', email, password: 'TestPass1!' });
    token = regRes.body.token;
  });

  test('creates a payment', async () => {
    const res = await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
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

  test('rejects invalid method', async () => {
    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'XYZ-5678', method: 'Cripto', amount: 200 })
      .expect(400);
  });

  test('rejects missing fields', async () => {
    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'XYZ-5678' })
      .expect(400);
  });
});

describe('GET /api/payments', () => {
  let token;

  beforeEach(async () => {
    const email = `pay_get_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'PayGet', email, password: 'TestPass1!' });
    token = regRes.body.token;

    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'ABC-1234', method: 'Efectivo', amount: 150 });
  });

  test('gets authenticated user payments with pagination', async () => {
    const res = await request(app)
      .get('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(1);
    expect(res.body.pagination).toMatchObject({ page: 1, limit: 20, total: 1 });
  });
});

describe('GET /api/payments/user/:userId', () => {
  let token;
  let userId;

  beforeEach(async () => {
    const email = `pay_uid_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'PayUid', email, password: 'TestPass1!' });
    token = regRes.body.token;
    userId = regRes.body.userId;

    await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'ABC-1234', method: 'Efectivo', amount: 150 });
  });

  test('gets payments by userId (self)', async () => {
    const res = await request(app)
      .get(`/api/payments/user/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body.pagination.total).toBe(1);
  });

  test('rejects access to other user payments without admin', async () => {
    const email2 = `pay_other_${Date.now()}@test.com`;
    const regRes2 = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Other', email: email2, password: 'TestPass1!' });

    // user2 es 'user' (no admin), intenta acceder a pagos de user1
    await request(app)
      .get(`/api/payments/user/${userId}`)
      .set('Authorization', `Bearer ${regRes2.body.token}`)
      .expect(403);
  });
});

describe('PUT /api/payments/:id', () => {
  let token;
  let paymentId;

  beforeEach(async () => {
    const email = `pay_put_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'PayPut', email, password: 'TestPass1!' });
    token = regRes.body.token;

    const payRes = await request(app)
      .post('/api/payments')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'ABC-1234', method: 'Efectivo', amount: 150 });

    paymentId = payRes.body._id;
  });

  test('updates payment status', async () => {
    const res = await request(app)
      .put(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'Pagado' })
      .expect(200);

    expect(res.body.status).toBe('Pagado');
  });

  test('rejects invalid status', async () => {
    await request(app)
      .put(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${token}`)
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
