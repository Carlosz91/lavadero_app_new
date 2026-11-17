const mongoose = require('mongoose');

// Contador atómico de autos agendados por día (clave 'YYYY-MM-DD' en hora local del negocio).
const dayCapacitySchema = new mongoose.Schema({
  date: { type: String, required: true, unique: true },
  count: { type: Number, required: true, default: 0, min: 0 },
});

module.exports = mongoose.model('DayCapacity', dayCapacitySchema);
