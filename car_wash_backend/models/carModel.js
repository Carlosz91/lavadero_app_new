const mongoose = require('mongoose');

const carSchema = new mongoose.Schema({
  plate: { type: String, required: true, trim: true },
  model: { type: String, required: true, trim: true },
  brand: { type: String, required: true, trim: true },
  washType: {
    type: String,
    required: true,
    enum: ['Básico', 'Premium', 'Premium Plus', 'Completo', 'Detailing', 'Full Package'],
  },
  amount: { type: Number, required: true, min: 0 },
  scheduledDate: { type: Date },
  scheduledTime: { type: String },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  status: {
    type: String,
    default: 'Pendiente',
    enum: ['Pendiente', 'En Progreso', 'Completado', 'Cancelado'],
  },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now },
});

carSchema.pre('save', function (next) {
  this.updatedAt = new Date();
  next();
});

carSchema.index({ userId: 1, createdAt: -1 });

const Car = mongoose.model('Car', carSchema);

module.exports = Car;
