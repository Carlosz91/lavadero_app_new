const mongoose = require('mongoose');

const idempotencySchema = new mongoose.Schema({
  key: { type: String, required: true, unique: true, index: true },
  response: {
    status: { type: Number, required: true },
    body: { type: mongoose.Schema.Types.Mixed, required: true },
  },
  createdAt: { type: Date, default: Date.now, expires: 86400 },
});

module.exports = mongoose.model('Idempotency', idempotencySchema);
