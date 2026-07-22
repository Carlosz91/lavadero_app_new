const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    // ✅ Validar formato email
    match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  },
  password: {
    type: String,
    required: false,
    minlength: 8,
  },
  googleId: {
    type: String,
    default: null,
    index: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  // ✅ Field para intentos fallidos de login
  loginAttempts: {
    type: Number,
    default: 0,
  },
  // ✅ Field para bloqueo temporal después de N intentos
  lockUntil: {
    type: Date,
    default: null,
  },
  // ✅ Field para roles/permisos
  role: {
    type: String,
    enum: ['user', 'admin', 'staff'],
    default: 'user',
  },
  // ✅ Field para email verificado
  emailVerified: {
    type: Boolean,
    default: false,
  },
  verificationToken: {
    type: String,
    default: null,
  },
}, { timestamps: true });

// Middleware para hashear la contraseña antes de guardar
userSchema.pre('save', async function (next) {
  if (!this.isModified('password') || !this.password) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Método para comparar contraseñas
userSchema.methods.comparePassword = async function (plainPassword) {
  // Compara la contraseña en texto plano con la contraseña hasheada
  return await bcrypt.compare(plainPassword, this.password);
};

// ✅ Método para incrementar intentos fallidos
userSchema.methods.incLoginAttempts = async function () {
  // Si la cuenta está desbloqueada, reset intentos
  if (this.lockUntil && this.lockUntil < new Date()) {
    return this.updateOne({
      $set: { loginAttempts: 1, lockUntil: null }
    });
  }

  // Incrementar intentos
  const updates = { $inc: { loginAttempts: 1 } };

  // Bloquear cuenta después de 5 intentos por 30 minutos
  if (this.loginAttempts + 1 >= 5) {
    updates.$set = { lockUntil: new Date(Date.now() + 30 * 60 * 1000) };
  }

  return this.updateOne(updates);
};

// ✅ Método para resetear intentos fallidos
userSchema.methods.resetLoginAttempts = async function () {
  return this.updateOne({
    $set: { loginAttempts: 0, lockUntil: null }
  });
};

// ✅ Método para verificar si cuenta está bloqueada
userSchema.methods.isLocked = function () {
  return this.lockUntil && this.lockUntil > new Date();
};

module.exports = mongoose.model('User', userSchema);
