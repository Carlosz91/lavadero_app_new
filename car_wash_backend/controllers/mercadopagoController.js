const mercadopago = require('mercadopago');
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { ValidationError } = require('../utils/AppError');

mercadopago.configure({
  access_token: process.env.MP_ACCESS_TOKEN,
});

const HOST = process.env.HOST || 'http://localhost:5000';

exports.createPreference = async (req, res, next) => {
  try {
    const { plate, amount, description, carId } = req.body;
    const userId = req.user.id;

    if (!plate || !amount || amount <= 0) {
      throw new ValidationError('Placa y monto son requeridos');
    }

    const payment = new Payment({
      userId,
      plate: plate.trim().toUpperCase(),
      method: 'Mercado Pago',
      amount,
      status: 'Pendiente',
      carId: carId || null,
      description: description || `Lavado - ${plate}`,
    });
    await payment.save();

    const preference = {
      items: [
        {
          id: payment._id.toString(),
          title: description || `Lavado de veh\u00edculo ${plate}`,
          quantity: 1,
          unit_price: Number(amount),
          currency_id: 'PYG',
        },
      ],
      payer: { id: userId },
      back_urls: {
        success: `${HOST}/api/mercadopago/success?paymentId=${payment._id}`,
        failure: `${HOST}/api/mercadopago/failure?paymentId=${payment._id}`,
        pending: `${HOST}/api/mercadopago/pending?paymentId=${payment._id}`,
      },
      auto_return: 'approved',
      notification_url: `${HOST}/api/mercadopago/webhook`,
      external_reference: payment._id.toString(),
    };

    const mpResponse = await mercadopago.preferences.create(preference);
    const initPoint = mpResponse.body.sandbox_init_point || mpResponse.body.init_point;

    logger.info('Preferencia MP creada', { paymentId: payment._id, amount });

    res.status(201).json({
      paymentId: payment._id,
      initPoint,
      preferenceId: mpResponse.body.id,
    });
  } catch (err) {
    logger.error('Error creando preferencia MP', { error: err.message });
    next(err);
  }
};

exports.success = async (req, res) => {
  const { paymentId } = req.query;
  if (paymentId) {
    await Payment.findByIdAndUpdate(paymentId, { status: 'Pagado' });
    logger.info('Pago MP exitoso', { paymentId });
  }
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#f0fdf4;"><div style="text-align:center;"><h1 style="color:#16a34a;">\u2705 Pago exitoso</h1><p>Gracias por tu pago. Ya puedes cerrar esta ventana.</p></div></body></html>`);
};

exports.failure = async (req, res) => {
  const { paymentId } = req.query;
  logger.warn('Pago MP fallido', { paymentId });
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#fef2f2;"><div style="text-align:center;"><h1 style="color:#dc2626;">\u274c Pago cancelado</h1><p>El pago no se complet\u00f3. Intenta de nuevo.</p></div></body></html>`);
};

exports.pending = async (req, res) => {
  const { paymentId } = req.query;
  logger.info('Pago MP pendiente', { paymentId });
  res.send(`<html><body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#fefce8;"><div style="text-align:center;"><h1 style="color:#ca8a04;">\u23f3 Pago pendiente</h1><p>Tu pago est\u00e1 siendo procesado.</p></div></body></html>`);
};

exports.webhook = async (req, res) => {
  try {
    const { type, data } = req.body;
    if (type === 'payment' && data?.id) {
      const mpPayment = await mercadopago.payment.get(data.id);
      const status = mpPayment.body.status;
      const externalRef = mpPayment.body.external_reference;

      if (externalRef && status === 'approved') {
        await Payment.findByIdAndUpdate(externalRef, { status: 'Pagado' });
        logger.info('Webhook MP: pago aprobado', { paymentId: externalRef });
      }
    }
    res.status(200).send('OK');
  } catch (err) {
    logger.error('Error en webhook MP', { error: err.message });
    res.status(200).send('OK');
  }
};
