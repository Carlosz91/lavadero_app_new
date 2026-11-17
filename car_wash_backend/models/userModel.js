const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { USER_ROLES } = require('../config/constants');

// Bloqueo progresivo: un bloqueo aislado (p. ej. alguien probando claves sobre la
// cuenta de otro) cuesta poco a la víctima; la insistencia escala el castigo.
const LOCK_MINUTES = [5, 15, 60];

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      // ✅ Validar formato email
      match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
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
    // Cuántas veces se bloqueó seguida (se reinicia con un login exitoso).
    lockCount: {
      type: Number,
      default: 0,
    },
    // ✅ Field para roles/permisos
    role: {
      type: String,
      enum: USER_ROLES,
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
    // ✅ Fields para reset de contraseña (token hasheado con sha256, expira en 15 min)
    resetPasswordToken: {
      type: String,
      default: null,
      index: true,
    },
    resetPasswordExpires: {
      type: Date,
      default: null,
    },
    // Sesiones de refresh activas (solo hash sha256 del jti; un solo uso, rotan)
    refreshSessions: {
      type: [
        {
          _id: false,
          jtiHash: { type: String, required: true },
          expiresAt: { type: Date, required: true },
        },
      ],
      default: [],
      select: false,
    },
  },
  { timestamps: true }
);

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
      $set: { loginAttempts: 1, lockUntil: null },
    });
  }

  // Incrementar intentos
  const updates = { $inc: { loginAttempts: 1 } };

  // Bloquear tras 5 intentos; la duración crece con los bloqueos repetidos.
  if (this.loginAttempts + 1 >= 5) {
    const minutes = LOCK_MINUTES[Math.min(this.lockCount || 0, LOCK_MINUTES.length - 1)];
    updates.$set = { lockUntil: new Date(Date.now() + minutes * 60 * 1000) };
    updates.$inc.lockCount = 1;
  }

  return this.updateOne(updates);
};

// ✅ Método para resetear intentos fallidos
userSchema.methods.resetLoginAttempts = async function () {
  return this.updateOne({
    $set: { loginAttempts: 0, lockUntil: null, lockCount: 0 },
  });
};

// ✅ Método para verificar si cuenta está bloqueada
userSchema.methods.isLocked = function () {
  return this.lockUntil && this.lockUntil > new Date();
};

module.exports = mongoose.model('User', userSchema);
