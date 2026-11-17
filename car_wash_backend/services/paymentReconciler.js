const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');

const STALE_AFTER_MS = 5 * 60 * 1000; // dar tiempo al webhook/redirect normales
const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000; // checkouts de Stripe expiran mucho antes
const BATCH = 100;

/**
 * Concilia con Stripe los pagos Pendiente que tienen un checkout abierto.
 * Cubre el caso en que el cobro se hizo pero ni el webhook ni la página
 * /success llegaron (app cerrada, webhook caído).
 */
const reconcileOnce = async (getStripe, now = Date.now()) => {
  const pending = await Payment.find({
    status: 'Pendiente',
    checkoutSessionId: { $ne: null },
    updatedAt: { $lt: new Date(now - STALE_AFTER_MS), $gt: new Date(now - MAX_AGE_MS) },
  }).limit(BATCH);

  const result = { checked: pending.length, paid: 0, expired: 0, failed: 0 };

  for (const payment of pending) {
    try {
      const session = await getStripe().checkout.sessions.retrieve(payment.checkoutSessionId);

      if (session.payment_status === 'paid') {
        const updated = await Payment.findOneAndUpdate(
          { _id: payment._id, status: 'Pendiente' },
          { status: 'Pagado', method: 'Stripe' }
        );
        if (updated) {
          result.paid += 1;
          logger.info('Conciliación: pago Stripe confirmado', { paymentId: payment._id });
        }
      } else if (session.status === 'expired') {
        // Checkout vencido sin cobro: se libera para que el usuario pueda reintentar.
        await Payment.updateOne({ _id: payment._id }, { checkoutSessionId: null });
        result.expired += 1;
      }
    } catch (err) {
      result.failed += 1;
      logger.warn('Conciliación: no se pudo consultar la sesión', {
        paymentId: payment._id,
        error: err.message,
      });
    }
  }

  return result;
};

/** Arranca la conciliación periódica. Devuelve una función para detenerla. */
const startReconciler = (getStripe) => {
  const minutes = Number(process.env.RECONCILE_INTERVAL_MIN || 10);
  if (!process.env.STRIPE_SECRET_KEY || !(minutes > 0)) return () => {};

  const timer = setInterval(
    () => {
      reconcileOnce(getStripe).catch((err) =>
        logger.error('Conciliación de pagos falló', { error: err.message })
      );
    },
    minutes * 60 * 1000
  );
  timer.unref();
  logger.info(`Conciliación de pagos Stripe cada ${minutes} min`);
  return () => clearInterval(timer);
};

module.exports = { reconcileOnce, startReconciler };
