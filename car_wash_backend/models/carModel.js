const mongoose = require('mongoose');
const { WASH_TYPES, CAR_STATUSES } = require('../config/constants');

const carSchema = new mongoose.Schema({
  plate: { type: String, required: true, trim: true },
  model: { type: String, required: true, trim: true },
  brand: { type: String, required: true, trim: true },
  color: { type: String, default: null, trim: true },
  washType: {
    type: String,
    required: true,
    enum: WASH_TYPES,
  },
  amount: { type: Number, required: true, min: 0 },
  scheduledDate: { type: Date },
  scheduledTime: { type: String },
  // Día ('YYYY-MM-DD', hora del negocio) cuyo cupo ocupa este auto; se libera al cancelar.
  capacityKey: { type: String, default: null },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  status: {
    type: String,
    default: 'Pendiente',
    enum: CAR_STATUSES,
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

carSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

carSchema.index({ userId: 1, createdAt: -1 });
// Reportes y cupo: consultas por fecha agendada, creación y estado.
carSchema.index({ scheduledDate: 1 });
carSchema.index({ createdAt: -1 });
carSchema.index({ status: 1, updatedAt: -1 });

const Car = mongoose.model('Car', carSchema);

module.exports = Car;
