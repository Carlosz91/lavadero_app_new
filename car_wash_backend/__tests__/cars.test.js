require('./helpers/setup');
const request = require('supertest');
const app = require('../server');

describe('POST /api/cars/registercar', () => {
  let token;

  beforeEach(async () => {
    const email = `cars_reg_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Cars', email, password: 'TestPass1!' });
    token = regRes.body.token;
  });

  test('registers a car with valid data', async () => {
    const res = await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-${Date.now()}-1`)
      .send({ plate: 'XYZ-5678', brand: 'Honda', model: 'Civic', washType: 'Básico', amount: 80 })
      .expect(201);

    expect(res.body.car.plate).toBe('XYZ-5678');
    expect(res.body.car.status).toBe('Pendiente');
  });

  test('rejects without auth', async () => {
    await request(app)
      .post('/api/cars/registercar')
      .send({ plate: 'XYZ-5678', brand: 'Honda', model: 'Civic', washType: 'Básico', amount: 80 })
      .expect(401);
  });

  test('rejects invalid wash type', async () => {
    await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'XYZ-5678', brand: 'Honda', model: 'Civic', washType: 'Ultra', amount: 80 })
      .expect(400);
  });

  test('rejects missing required fields', async () => {
    await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'XYZ-5678' })
      .expect(400);
  });

  test('rejects amount <= 0', async () => {
    await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .send({ plate: 'XYZ-5678', brand: 'Honda', model: 'Civic', washType: 'Básico', amount: 0 })
      .expect(400);
  });
});

describe('GET /api/cars/status/:userId', () => {
  let token;
  let userId;

  beforeEach(async () => {
    const email = `cars_get_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'CarsGet', email, password: 'TestPass1!' });
    token = regRes.body.token;
    userId = regRes.body.userId;

    await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-${Date.now()}-2`)
      .send({ plate: 'ABC-1234', brand: 'Toyota', model: 'Corolla', washType: 'Premium', amount: 150 });
  });

  test('gets user cars with pagination', async () => {
    const res = await request(app)
      .get(`/api/cars/status/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(1);
    expect(res.body.pagination).toMatchObject({ page: 1, limit: 20, total: 1, pages: 1 });
  });

  test('rejects unauthorized access', async () => {
    await request(app)
      .get(`/api/cars/status/${userId}`)
      .expect(401);
  });
});

describe('PUT /api/cars/update-status/:carId', () => {
  let token;
  let carId;

  beforeEach(async () => {
    const email = `cars_upd_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'CarsUpd', email, password: 'TestPass1!' });
    token = regRes.body.token;

    const carRes = await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-${Date.now()}-3`)
      .send({ plate: 'ABC-1234', brand: 'Toyota', model: 'Corolla', washType: 'Premium', amount: 150 });

    carId = carRes.body.car._id;
  });

  test('updates to En Progreso', async () => {
    const res = await request(app)
      .put(`/api/cars/update-status/${carId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'En Progreso' })
      .expect(200);

    expect(res.body.car.status).toBe('En Progreso');
  });

  test('rejects invalid transition', async () => {
    await request(app)
      .put(`/api/cars/update-status/${carId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'Completado' })
      .expect(400);
  });

  test('rejects invalid status value', async () => {
    await request(app)
      .put(`/api/cars/update-status/${carId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'Invalido' })
      .expect(400);
  });
});

describe('PUT /api/cars/close-car/:carId', () => {
  let token;
  let carId;

  beforeEach(async () => {
    const email = `cars_cls_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'CarsCls', email, password: 'TestPass1!' });
    token = regRes.body.token;

    const carRes = await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-${Date.now()}-4`)
      .send({ plate: 'ABC-1234', brand: 'Toyota', model: 'Corolla', washType: 'Premium', amount: 150 });

    carId = carRes.body.car._id;
  });

  test('closes car as completed', async () => {
    await request(app)
      .put(`/api/cars/update-status/${carId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ status: 'En Progreso' });

    const res = await request(app)
      .put(`/api/cars/close-car/${carId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.car.status).toBe('Completado');
  });

  test('rejects close on pending car', async () => {
    await request(app)
      .put(`/api/cars/close-car/${carId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(400);
  });
});

describe('GET /api/cars/stats/:userId', () => {
  let token;
  let userId;

  beforeEach(async () => {
    const email = `cars_st_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'CarsSt', email, password: 'TestPass1!' });
    token = regRes.body.token;
    userId = regRes.body.userId;

    await request(app)
      .post('/api/cars/registercar')
      .set('Authorization', `Bearer ${token}`)
      .set('Idempotency-Key', `idem-${Date.now()}-5`)
      .send({ plate: 'ABC-1234', brand: 'Toyota', model: 'Corolla', washType: 'Premium', amount: 150 });
  });

  test('gets car stats', async () => {
    const res = await request(app)
      .get(`/api/cars/stats/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body).toHaveProperty('stats');
    expect(res.body.stats.Pendiente.count).toBe(1);
  });
});
