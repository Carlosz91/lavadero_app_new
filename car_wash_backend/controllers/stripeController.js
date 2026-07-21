const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { ValidationError } = require('../utils/AppError');

const HOST = process.env.STRIPE_REDIRECT_HOST || 'http://10.0.2.2:5000';

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
      success_url: `${HOST}/api/stripe/success?session_id={CHECKOUT_SESSION_ID}&paymentId=${payment._id}`,
      cancel_url: `${HOST}/api/stripe/cancel?paymentId=${payment._id}`,
      client_reference_id: payment._id.toString(),
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

exports.success = async (req, res) => {
  const { paymentId, session_id } = req.query;
  if (paymentId) {
    await Payment.findByIdAndUpdate(paymentId, { status: 'Pagado' });
    logger.info('Pago Stripe exitoso', { paymentId, sessionId: session_id });
  }
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#f0fdf4;"><div style="text-align:center;"><h1 style="color:#16a34a;">\u2705 Pago exitoso</h1><p>Gracias por tu pago. Ya puedes cerrar esta ventana.</p></div></body></html>`);
};

exports.cancel = async (req, res) => {
  const { paymentId } = req.query;
  logger.warn('Pago Stripe cancelado', { paymentId });
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#fef2f2;"><div style="text-align:center;"><h1 style="color:#dc2626;">\u274c Pago cancelado</h1><p>El pago no se complet\u00f3. Intenta de nuevo.</p></div></body></html>`);
};
