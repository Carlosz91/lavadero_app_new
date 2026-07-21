require('./helpers/setup');
const request = require('supertest');
const app = require('../server');

describe('POST /api/auth/register', () => {
  test('registers a new user', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Test', email: `a1_${Date.now()}@test.com`, password: 'TestPass1!' })
      .expect(201);

    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('refreshToken');
    expect(res.body).toHaveProperty('userId');
  });

  test('rejects duplicate email', async () => {
    const email = `dup_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'First', email, password: 'TestPass1!' });

    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Second', email, password: 'TestPass1!' })
      .expect(400);
  });

  test('rejects missing fields', async () => {
    await request(app)
      .post('/api/auth/register')
      .send({ email: 'x@test.com' })
      .expect(400);
  });

  test('rejects weak password', async () => {
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Weak', email: `weak_${Date.now()}@test.com`, password: '123' })
      .expect(400);
  });

  test('rejects invalid email', async () => {
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Bad', email: 'not-email', password: 'TestPass1!' })
      .expect(400);
  });
});

describe('POST /api/auth/login', () => {
  let email;
  beforeEach(async () => {
    email = `login_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Login', email, password: 'TestPass1!' });
  });

  test('logs in with valid credentials', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'TestPass1!' })
      .expect(200);

    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('refreshToken');
    expect(res.body.user.email).toBe(email);
  });

  test('rejects invalid password', async () => {
    await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'WrongPass1!' })
      .expect(401);
  });

  test('rejects non-existent user', async () => {
    await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@test.com', password: 'TestPass1!' })
      .expect(401);
  });

  test('rejects empty body', async () => {
    await request(app)
      .post('/api/auth/login')
      .send({})
      .expect(400);
  });
});

describe('POST /api/auth/refresh', () => {
  let refreshToken;

  beforeEach(async () => {
    const email = `refresh_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Refresh', email, password: 'TestPass1!' });

    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'TestPass1!' });

    refreshToken = loginRes.body.refreshToken;
  });

  test('refreshes token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(200);

    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('refreshToken');
  });

  test('rejects invalid refresh token', async () => {
    await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: 'invalid-token' })
      .expect(401);
  });

  test('rejects missing refresh token', async () => {
    await request(app)
      .post('/api/auth/refresh')
      .send({})
      .expect(400);
  });
});

describe('PUT /api/auth/change-password', () => {
  let token;
  let password;

  beforeEach(async () => {
    password = 'TestPass1!';
    const email = `chpwd_${Date.now()}@test.com`;
    const regRes = await request(app)
      .post('/api/auth/register')
      .send({ name: 'ChPwd', email, password });

    token = regRes.body.token;
  });

  test('changes password successfully', async () => {
    const res = await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: password, newPassword: 'NewPass123!' })
      .expect(200);

    expect(res.body.message).toBe('Contraseña actualizada exitosamente');
  });

  test('rejects wrong current password', async () => {
    await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: 'WrongPass1!', newPassword: 'NewPass123!' })
      .expect(401);
  });

  test('rejects weak new password', async () => {
    await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: password, newPassword: '123' })
      .expect(400);
  });

  test('rejects same password', async () => {
    await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: password, newPassword: password })
      .expect(400);
  });

  test('rejects without auth', async () => {
    await request(app)
      .put('/api/auth/change-password')
      .send({ currentPassword: 'x', newPassword: 'NewPass123!' })
      .expect(401);
  });
});
