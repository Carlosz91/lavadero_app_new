require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const User = require('../models/userModel');

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
    await request(app).post('/api/auth/register').send({ email: 'x@test.com' }).expect(400);
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
    await request(app).post('/api/auth/login').send({ email, password: 'WrongPass1!' }).expect(401);
  });

  test('rejects non-existent user', async () => {
    await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@test.com', password: 'TestPass1!' })
      .expect(401);
  });

  test('rejects empty body', async () => {
    await request(app).post('/api/auth/login').send({}).expect(400);
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
    const res = await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(200);

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
    await request(app).post('/api/auth/refresh').send({}).expect(400);
  });

  test('rejects access token used as refresh token', async () => {
    const email = `refresh_access_${Date.now()}@test.com`;
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ name: 'RefreshAccess', email, password: 'TestPass1!' })
      .expect(201);
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email, password: 'TestPass1!' })
      .expect(200);

    // Un access token no debe servir para renovar sesión
    await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: loginRes.body.token })
      .expect(401);

    // Ni el token devuelto por register
    await request(app).post('/api/auth/refresh').send({ refreshToken: reg.body.token }).expect(401);
  });
});

describe('POST /api/auth/forgot-password', () => {
  test('responds generically for existing user (no enumeration)', async () => {
    const email = `forgot_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'Forgot', email, password: 'TestPass1!' });

    const res = await request(app).post('/api/auth/forgot-password').send({ email }).expect(200);

    expect(res.body.message).toContain('Si el correo está registrado');
  });

  test('responds generically for unknown email (no enumeration)', async () => {
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: `nobody_${Date.now()}@test.com` })
      .expect(200);

    expect(res.body.message).toContain('Si el correo está registrado');
  });

  test('responds generically for Google-only accounts', async () => {
    const email = `gapp_${Date.now()}@test.com`;
    await User.create({ email, name: 'GoogleOnly' }); // sin password

    const res = await request(app).post('/api/auth/forgot-password').send({ email }).expect(200);

    expect(res.body.message).toContain('Si el correo está registrado');
  });

  test('rejects invalid email', async () => {
    await request(app).post('/api/auth/forgot-password').send({ email: 'not-email' }).expect(400);
  });
});

describe('POST /api/auth/reset-password', () => {
  test('rejects invalid code', async () => {
    await request(app)
      .post('/api/auth/reset-password')
      .send({ resetToken: 'no-such-token', newPassword: 'NewPass123!' })
      .expect(400);
  });

  test('rejects weak new password', async () => {
    await request(app)
      .post('/api/auth/reset-password')
      .send({ resetToken: 'no-such-token', newPassword: '123' })
      .expect(400);
  });

  test('resets password with valid code and allows login', async () => {
    const email = `reset_flow_${Date.now()}@test.com`;
    await request(app)
      .post('/api/auth/register')
      .send({ name: 'ResetFlow', email, password: 'TestPass1!' });

    const mailer = require('../utils/mailer');
    mailer.outbox.length = 0;

    await request(app).post('/api/auth/forgot-password').send({ email }).expect(200);

    const mail = mailer.outbox.find((m) => m.to === email);
    expect(mail).toBeTruthy();
    const code = mail.text.match(/Código: (\S+)/)?.[1];
    expect(code).toBeTruthy();

    await request(app)
      .post('/api/auth/reset-password')
      .send({ resetToken: code, newPassword: 'NewPass123!' })
      .expect(200);

    // El código es de un solo uso
    await request(app)
      .post('/api/auth/reset-password')
      .send({ resetToken: code, newPassword: 'NewPass123!' })
      .expect(400);

    // Login con la contraseña nueva
    await request(app).post('/api/auth/login').send({ email, password: 'NewPass123!' }).expect(200);
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

describe('Sesiones: access 5m, rotación y revocación del refresh', () => {
  const jwt = require('jsonwebtoken');
  const register = async (tag) => {
    const email = `${tag}_${Date.now()}@test.com`;
    const res = await request(app)
      .post('/api/auth/register')
      .send({ name: 'Sess', email, password: 'TestPass1!' })
      .expect(201);
    return { email, ...res.body };
  };

  test('el access token expira en 5 minutos', async () => {
    const { token } = await register('ttl');
    const { iat, exp } = jwt.decode(token);
    expect(exp - iat).toBe(5 * 60);
  });

  test('el refresh rota: el token viejo ya no sirve', async () => {
    const { refreshToken } = await register('rot');
    const r1 = await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(200);
    expect(r1.body.refreshToken).not.toBe(refreshToken);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401);
  });

  test('reutilizar un refresh viejo revoca toda la familia de sesiones', async () => {
    const { refreshToken } = await register('reuse');
    const r1 = await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(200);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401); // reuso
    await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: r1.body.refreshToken })
      .expect(401);
  });

  test('logout revoca el refresh token', async () => {
    const { token, refreshToken } = await register('logout');
    await request(app)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${token}`)
      .send({ refreshToken })
      .expect(200);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401);
  });

  test('cambiar la contraseña cierra las demás sesiones', async () => {
    const { token, refreshToken } = await register('chpw');
    await request(app)
      .put('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: 'TestPass1!', newPassword: 'NewPass2@x' })
      .expect(200);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401);
  });
});

describe('Admin inicial', () => {
  const reg = (email) =>
    request(app)
      .post('/api/auth/register')
      .send({ name: 'Admin Test', email, password: 'TestPass1!' });

  test('fuera de producción el primer usuario es admin y el segundo no', async () => {
    const a = await reg(`first_${Date.now()}@test.com`).expect(201);
    const b = await reg(`second_${Date.now()}@test.com`).expect(201);
    expect(a.body.user.role).toBe('admin');
    expect(b.body.user.role).toBe('user');
  });

  test('en producción el primer usuario NO es admin', async () => {
    // Se llama al controlador directo: NODE_ENV=production activaría los rate limiters.
    const { registerUser } = require('../controllers/authController');
    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    let status;
    let body;
    const res = {
      status: (c) => ({
        json: (b) => {
          status = c;
          body = b;
        },
      }),
    };
    try {
      await registerUser(
        {
          body: {
            name: 'Prod Admin',
            email: `prod_${Date.now()}@test.com`,
            password: 'TestPass1!',
          },
        },
        res,
        (err) => {
          throw err;
        }
      );
    } finally {
      process.env.NODE_ENV = prev;
    }
    expect(status).toBe(201);
    expect(body.user.role).toBe('user');
  });
});
