const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  plate: { type: String, required: true },
  method: { type: String, required: true, enum: ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago', 'Stripe', 'Otro'] },
  amount: { type: Number, required: true, min: 0 },
  status: { type: String, default: 'Pendiente', enum: ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'] },
  date: { type: Date, default: Date.now },
  carId: { type: mongoose.Schema.Types.ObjectId, ref: 'Car', default: null },
}, { timestamps: true });

paymentSchema.index({ userId: 1, date: -1 });

module.exports = mongoose.model('Payment', paymentSchema);
