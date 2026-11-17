const mongoose = require('mongoose');
const { PAYMENT_METHODS, PAYMENT_STATUSES } = require('../config/constants');

const paymentSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    plate: { type: String, required: true },
    method: { type: String, required: true, enum: PAYMENT_METHODS },
    amount: { type: Number, required: true, min: 0 },
    status: { type: String, default: 'Pendiente', enum: PAYMENT_STATUSES },
    date: { type: Date, default: Date.now },
    carId: { type: mongoose.Schema.Types.ObjectId, ref: 'Car', default: null },
    // Id de la sesión de Checkout Stripe activa: permite reusar el checkout en
    // reintentos y detectar cobros ya realizados (evita doble cobro).
    checkoutSessionId: { type: String, default: null },
  },
  { timestamps: true }
);

paymentSchema.index({ userId: 1, date: -1 });
// Reportes (por estado y fecha) y conciliación con Stripe.
paymentSchema.index({ status: 1, date: -1 });
paymentSchema.index({ status: 1, checkoutSessionId: 1, updatedAt: 1 });

module.exports = mongoose.model('Payment', paymentSchema);
