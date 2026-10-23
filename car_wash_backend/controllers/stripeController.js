const Stripe = require('stripe');
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { AppError, ValidationError, ForbiddenError } = require('../utils/AppError');

const HOST = process.env.STRIPE_REDIRECT_HOST || 'http://10.0.2.2:5000';
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;

// Instancia lazy: el servidor arranca aunque STRIPE_SECRET_KEY no esté definida
// y los endpoints de Stripe devuelven un 500 claro en su lugar.
let stripeClient = null;
const getStripe = () => {
  if (!process.env.STRIPE_SECRET_KEY) {
    throw new AppError('Stripe no está configurado en el servidor (STRIPE_SECRET_KEY)', 500, 'SERVER_CONFIG');
  }
  if (!stripeClient) {
    stripeClient = new Stripe(process.env.STRIPE_SECRET_KEY);
  }
  return stripeClient;
};

/**
 * @desc    Crea sesión de pago Stripe. Requiere un paymentId existente (creado por el sistema o admin); el monto siempre proviene del pago, nunca del cliente.
 * @route   POST /api/stripe/create-checkout-session
 * @access  Private
 */
exports.createCheckoutSession = async (req, res, next) => {
  try {
    const { plate, description, paymentId } = req.body;
    const userId = req.user.id;

    if (!paymentId) {
      throw new ValidationError('paymentId es requerido: el pago debe existir antes de iniciar el checkout');
    }

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      throw new ValidationError('Pago no encontrado');
    }

    const isStaff = ['admin', 'staff'].includes(req.user.role);
    if (!isStaff && payment.userId.toString() !== userId) {
      throw new ForbiddenError('No tienes permiso para pagar este pago');
    }

    if (payment.status !== 'Pendiente') {
      throw new ValidationError('Este pago ya fue procesado');
    }

    // Un pago solo tiene UN checkout activo: reintentos reutilizan la sesión
    // abierta o detectan el cobro ya hecho. Sin esto, un reintento tras
    // fallar el redirect crearía un cobro NUEVO cada vez.
    if (payment.checkoutSessionId) {
      let existing = null;
      try {
        existing = await getStripe().checkout.sessions.retrieve(payment.checkoutSessionId);
      } catch (err) {
        logger.warn('No se pudo reutilizar el checkout anterior, se creará uno nuevo', { paymentId: payment._id, error: err.message });
      }
      if (existing?.payment_status === 'paid') {
        // El cobro ya se concretó pero aún no se marcó (webhook/success pendientes):
        // reconciliar acá en lugar de generar otro cobro.
        payment.status = 'Pagado';
        payment.method = 'Stripe';
        await payment.save();
        logger.info('Pago Stripe reconciliado al reintentar checkout', { paymentId: payment._id });
        throw new ValidationError('Este pago ya fue procesado');
      }
      if (existing?.status === 'open') {
        logger.info('Checkout Stripe: reutilizando sesión abierta', { paymentId: payment._id, sessionId: existing.id });
        return res.status(200).json({ paymentId: payment._id, url: existing.url, sessionId: existing.id });
      }
    }

    const finalPlate = payment.plate || plate;
    const finalAmount = payment.amount;

    const session = await getStripe().checkout.sessions.create({
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

    // Recordar la sesión activa: el reintento la reutiliza o detecta el cobro.
    await Payment.findByIdAndUpdate(payment._id, { checkoutSessionId: session.id });

    logger.info('Checkout Stripe creado', { paymentId: payment._id, sessionId: session.id, amount: finalAmount });

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
      const session = await getStripe().checkout.sessions.retrieve(session_id);
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
    if (!process.env.STRIPE_SECRET_KEY || !WEBHOOK_SECRET) {
      logger.error('Webhook de Stripe llamado sin STRIPE_SECRET_KEY o STRIPE_WEBHOOK_SECRET configurados');
      return res.status(503).send('Webhook no configurado en el servidor');
    }
    event = getStripe().webhooks.constructEvent(payload, sig, WEBHOOK_SECRET);
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
