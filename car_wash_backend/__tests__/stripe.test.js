process.env.STRIPE_SECRET_KEY = 'sk_test_dummy';
process.env.STRIPE_WEBHOOK_SECRET = 'whsec_dummy';

// Stripe simulado: ninguna prueba toca la red.
const mockStripe = {
  checkout: { sessions: { create: jest.fn(), retrieve: jest.fn() } },
  webhooks: { constructEvent: jest.fn() },
};
jest.mock('stripe', () => jest.fn(() => mockStripe));

require('./helpers/setup');
const request = require('supertest');
const app = require('../server');
const Payment = require('../models/paymentModel');

const register = async (name, email) => {
  const res = await request(app)
    .post('/api/auth/register')
    .send({ name, email, password: 'TestPass1!' });
  return { token: res.body.token, userId: res.body.userId };
};

const checkout = (token, paymentId) =>
  request(app)
    .post('/api/stripe/create-checkout-session')
    .set('Authorization', `Bearer ${token}`)
    .set('Idempotency-Key', `st-${Date.now()}-${Math.random()}`)
    .send({ paymentId });

let owner;
let other;
let payment;

beforeEach(async () => {
  jest.clearAllMocks();
  await register('Admin', `st_admin_${Date.now()}@test.com`); // primer usuario = admin
  owner = await register('Owner', `st_owner_${Date.now()}@test.com`);
  other = await register('Other', `st_other_${Date.now()}@test.com`);
  payment = await Payment.create({
    userId: owner.userId,
    plate: 'ABC-1234',
    method: 'Stripe',
    amount: 50000,
  });
});

describe('POST /api/stripe/create-checkout-session', () => {
  test('requiere paymentId', async () => {
    await checkout(owner.token, undefined).expect(400);
  });

  test('crea la sesión usando el monto del pago, no del cliente', async () => {
    mockStripe.checkout.sessions.create.mockResolvedValue({
      id: 'cs_1',
      url: 'https://stripe/pay',
    });
    const res = await checkout(owner.token, payment._id.toString()).expect(201);

    expect(res.body.url).toBe('https://stripe/pay');
    const args = mockStripe.checkout.sessions.create.mock.calls[0][0];
    expect(args.line_items[0].price_data.unit_amount).toBe(50000);
    expect(args.metadata.paymentId).toBe(payment._id.toString());
    const saved = await Payment.findById(payment._id);
    expect(saved.checkoutSessionId).toBe('cs_1');
  });

  test('otro usuario no puede pagar un pago ajeno', async () => {
    await checkout(other.token, payment._id.toString()).expect(403);
    expect(mockStripe.checkout.sessions.create).not.toHaveBeenCalled();
  });

  test('un pago ya procesado se rechaza', async () => {
    await Payment.findByIdAndUpdate(payment._id, { status: 'Pagado' });
    await checkout(owner.token, payment._id.toString()).expect(400);
  });

  test('reintento reutiliza la sesión abierta (sin doble cobro)', async () => {
    await Payment.findByIdAndUpdate(payment._id, { checkoutSessionId: 'cs_open' });
    mockStripe.checkout.sessions.retrieve.mockResolvedValue({
      id: 'cs_open',
      status: 'open',
      payment_status: 'unpaid',
      url: 'https://stripe/open',
    });
    const res = await checkout(owner.token, payment._id.toString()).expect(200);
    expect(res.body.url).toBe('https://stripe/open');
    expect(mockStripe.checkout.sessions.create).not.toHaveBeenCalled();
  });

  test('reintento con cobro ya hecho reconcilia el pago y no crea otro cobro', async () => {
    await Payment.findByIdAndUpdate(payment._id, { checkoutSessionId: 'cs_paid' });
    mockStripe.checkout.sessions.retrieve.mockResolvedValue({
      id: 'cs_paid',
      status: 'complete',
      payment_status: 'paid',
    });
    await checkout(owner.token, payment._id.toString()).expect(400);
    expect((await Payment.findById(payment._id)).status).toBe('Pagado');
    expect(mockStripe.checkout.sessions.create).not.toHaveBeenCalled();
  });
});

describe('GET /api/stripe/success', () => {
  test('NO marca como pagado si Stripe no cobró (session_id sin pagar)', async () => {
    mockStripe.checkout.sessions.retrieve.mockResolvedValue({
      id: 'cs_unpaid',
      payment_status: 'unpaid',
      metadata: { paymentId: payment._id.toString() },
    });
    await request(app).get('/api/stripe/success?session_id=cs_unpaid').expect(200);
    expect((await Payment.findById(payment._id)).status).toBe('Pendiente');
  });

  test('marca como pagado cuando Stripe confirma el cobro', async () => {
    mockStripe.checkout.sessions.retrieve.mockResolvedValue({
      id: 'cs_ok',
      payment_status: 'paid',
      metadata: { paymentId: payment._id.toString() },
    });
    await request(app).get('/api/stripe/success?session_id=cs_ok').expect(200);
    const saved = await Payment.findById(payment._id);
    expect(saved.status).toBe('Pagado');
    expect(saved.method).toBe('Stripe');
  });

  test('responde la página aunque Stripe falle', async () => {
    mockStripe.checkout.sessions.retrieve.mockRejectedValue(new Error('boom'));
    await request(app).get('/api/stripe/success?session_id=cs_x').expect(200);
    expect((await Payment.findById(payment._id)).status).toBe('Pendiente');
  });

  test('cancel responde la página de cancelación', async () => {
    const res = await request(app).get('/api/stripe/cancel').expect(200);
    expect(res.text).toContain('Pago cancelado');
  });
});

describe('POST /api/stripe/webhook', () => {
  const event = (paymentStatus = 'paid') => ({
    type: 'checkout.session.completed',
    data: {
      object: {
        id: 'cs_w',
        payment_status: paymentStatus,
        metadata: { paymentId: payment._id.toString() },
      },
    },
  });

  test('firma inválida => 400 y no cambia el pago', async () => {
    mockStripe.webhooks.constructEvent.mockImplementation(() => {
      throw new Error('bad signature');
    });
    await request(app)
      .post('/api/stripe/webhook')
      .set('stripe-signature', 'x')
      .set('Content-Type', 'application/json')
      .send('{}')
      .expect(400);
    expect((await Payment.findById(payment._id)).status).toBe('Pendiente');
  });

  test('checkout.session.completed pagado => Pagado', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(event('paid'));
    await request(app)
      .post('/api/stripe/webhook')
      .set('stripe-signature', 'ok')
      .set('Content-Type', 'application/json')
      .send('{}')
      .expect(200, { received: true });
    expect((await Payment.findById(payment._id)).status).toBe('Pagado');
  });

  test('evento sin cobro (unpaid) no marca el pago', async () => {
    mockStripe.webhooks.constructEvent.mockReturnValue(event('unpaid'));
    await request(app)
      .post('/api/stripe/webhook')
      .set('stripe-signature', 'ok')
      .set('Content-Type', 'application/json')
      .send('{}')
      .expect(200);
    expect((await Payment.findById(payment._id)).status).toBe('Pendiente');
  });

  test('es idempotente: un reintento no pisa un pago Cancelado/Reembolsado', async () => {
    await Payment.findByIdAndUpdate(payment._id, { status: 'Reembolsado' });
    mockStripe.webhooks.constructEvent.mockReturnValue(event('paid'));
    await request(app)
      .post('/api/stripe/webhook')
      .set('stripe-signature', 'ok')
      .set('Content-Type', 'application/json')
      .send('{}')
      .expect(200);
    expect((await Payment.findById(payment._id)).status).toBe('Reembolsado');
  });
});
