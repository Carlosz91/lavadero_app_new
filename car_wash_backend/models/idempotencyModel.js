const mongoose = require('mongoose');

const idempotencySchema = new mongoose.Schema({
  key: { type: String, required: true },
  // La clave solo vale para su dueño: sin esto, otro usuario podría recibir la
  // respuesta guardada de una petición ajena enviando la misma clave.
  userId: { type: String, required: true },
  // Huella de método + ruta + cuerpo: la misma clave con otra petición es un error.
  fingerprint: { type: String, required: true },
  response: {
    status: { type: Number, required: true },
    body: { type: mongoose.Schema.Types.Mixed, required: true },
  },
  createdAt: { type: Date, default: Date.now, expires: 86400 },
});

idempotencySchema.index({ userId: 1, key: 1 }, { unique: true });

module.exports = mongoose.model('Idempotency', idempotencySchema);
