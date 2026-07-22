const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { ValidationError } = require('../utils/AppError');

const HOST = process.env.STRIPE_REDIRECT_HOST || 'http://10.0.2.2:5000';
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

/**
 * @desc    Crea sesión de pago Stripe. Reutiliza paymentId existente o crea uno nuevo.
 * @route   POST /api/stripe/create-checkout-session
 * @access  Private
 */
exports.createCheckoutSession = async (req, res, next) => {
  try {
    const { plate, amount, description, carId, paymentId } = req.body;
    const userId = req.user.id;

    let payment;
    if (paymentId) {
      payment = await Payment.findById(paymentId);
      if (!payment) {
        throw new ValidationError('Pago no encontrado');
      }
      if (payment.status !== 'Pendiente') {
        throw new ValidationError('Este pago ya fue procesado');
      }
    } else {
      if (!plate || !amount || amount <= 0) {
        throw new ValidationError('Placa y monto son requeridos');
      }

      payment = new Payment({
        userId,
        plate: plate.trim().toUpperCase(),
        method: 'Stripe',
        amount,
        status: 'Pendiente',
        carId: carId || null,
      });
      await payment.save();
    }

    const finalPlate = payment.plate || plate;
    const finalAmount = payment.amount || amount;

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: 'pyg',
            product_data: {
              name: description || `Lavado de veh\u00edculo ${finalPlate}`,
            },
            unit_amount: Math.round(finalAmount),
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: `${HOST}/api/stripe/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${HOST}/api/stripe/cancel`,
      metadata: { paymentId: payment._id.toString(), userId },
    });

    logger.info('Checkout Stripe creado', { paymentId: payment._id, sessionId: session.id });

    res.status(201).json({
      paymentId: payment._id,
      url: session.url,
      sessionId: session.id,
    });
  } catch (err) {
    logger.error('Error creando checkout Stripe', { error: err.message });
    next(err);
  }
};

/**
 * @desc    Página HTML de confirmación de pago exitoso.
 *          También actualiza el pago como fallback por si el webhook no llega.
 * @route   GET /api/stripe/success
 * @access  Público (redirección Stripe)
 */
exports.success = async (req, res) => {
  const { session_id } = req.query;
  if (session_id) {
    try {
      const session = await stripe.checkout.sessions.retrieve(session_id);
      const paymentId = session.metadata?.paymentId;
      if (paymentId) {
        const payment = await Payment.findById(paymentId);
        if (payment && payment.status === 'Pendiente') {
          payment.status = 'Pagado';
          payment.method = 'Stripe';
          await payment.save();
          logger.info('Pago Stripe confirmado desde success page', { paymentId, sessionId: session_id });
        }
      }
    } catch (err) {
      logger.error('Error al confirmar pago desde success page', { error: err.message, sessionId: session_id });
    }
  }
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#f0fdf4;"><div style="text-align:center;"><h1 style="color:#16a34a;">\u2705 Pago exitoso</h1><p>Gracias por tu pago. Ya puedes cerrar esta ventana.</p></div></body></html>`);
};

/**
 * @desc    Página HTML de cancelación de pago
 * @route   GET /api/stripe/cancel
 * @access  Público (redirección Stripe)
 */
exports.cancel = async (req, res) => {
  logger.warn('Pago Stripe cancelado');
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#fef2f2;"><div style="text-align:center;"><h1 style="color:#dc2626;">\u274c Pago cancelado</h1><p>El pago no se complet\u00f3. Intenta de nuevo.</p></div></body></html>`);
};

/**
 * @desc    Webhook de Stripe con verificación de firma. Procesa checkout.session.completed y actualiza pago a Pagado.
 * @route   POST /api/stripe/webhook
 * @access  Público (firmado por Stripe)
 */
exports.webhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const payload = req.rawBody || req.body;

  let event;
  try {
    event = stripe.webhooks.constructEvent(payload, sig, WEBHOOK_SECRET);
  } catch (err) {
    logger.error('Firma de webhook Stripe inválida', { error: err.message });
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const paymentId = session.metadata?.paymentId;
    if (paymentId) {
      await Payment.findByIdAndUpdate(paymentId, { status: 'Pagado', method: 'Stripe' });
      logger.info('Webhook: pago Stripe confirmado', { paymentId, sessionId: session.id });
    }
  }

  res.json({ received: true });
};
