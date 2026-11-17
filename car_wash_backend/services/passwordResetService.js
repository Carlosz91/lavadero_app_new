const crypto = require('crypto');
const User = require('../models/userModel');
const logger = require('../utils/logger');
const mailer = require('../utils/mailer');
const { ValidationError } = require('../utils/AppError');

const sha256 = (v) => crypto.createHash('sha256').update(v).digest('hex');
const RESET_TTL_MS = 15 * 60 * 1000; // 15 minutos

/**
 * Genera un token de reset a partir de bytes aleatorios y guarda su hash sha256
 * en el usuario. El token plano nunca toca la base de datos.
 */
const issueResetToken = async (user) => {
  const token = crypto.randomBytes(32).toString('hex');
  user.resetPasswordToken = sha256(token);
  user.resetPasswordExpires = Date.now() + RESET_TTL_MS;
  await user.save();
  return token;
};

const resetEmailTemplate = (link, code) => `
  <p>Hola,</p>
  <p>Recibimos una solicitud para restablecer tu contraseña en Lavadero App.</p>
  <p><a href="${link}">Restablecer contraseña</a></p>
  <p>O copia este código en la app:</p>
  <p style="font-size:18px;font-weight:bold;letter-spacing:1px">${code}</p>
  <p>Si no fuiste tú, ignora este correo.</p>
  <p style="color:#888">El código expira en 15 minutos.</p>
`;

const resetTextTemplate = (code) =>
  `Recibimos una solicitud para restablecer tu contraseña en Lavadero App.\n\n` +
  `Código: ${code}\n\n` +
  `Ingresa este código en la app (o usa el enlace del correo si lo incluye).\n` +
  `El código expira en 15 minutos. Si no fuiste tú, ignora este correo.`;

/**
 * Solicita el reset: envía el código por email (SMTP) o, solo en desarrollo
 * sin SMTP, lo deja en los logs. No revela si el email existe: devuelve
 * normalmente en todos los casos.
 */
const requestReset = async (email) => {
  const user = await User.findOne({ email });
  // Las cuentas de Google no tienen contraseña local: nada que resetear por esta vía.
  if (!user || !user.password) return;

  const token = await issueResetToken(user);

  const frontendBase = process.env.APP_RESET_URL; // opcional: URL web de reset
  const link = frontendBase
    ? `${frontendBase.replace(/\/$/, '')}?token=${token}`
    : `http://localhost:3000/reset-password?token=${token}`;

  const sent = await mailer.sendMail(
    user.email,
    'Restablecer contraseña - Lavadero App',
    resetTextTemplate(token),
    resetEmailTemplate(link, token)
  );

  if (sent) {
    logger.info('Email de reset enviado', { userId: user._id });
  } else if (process.env.NODE_ENV === 'production') {
    logger.warn('SMTP no configurado en producción: no se pudo enviar el email de reset', {
      userId: user._id,
    });
  } else {
    // Fallback de desarrollo: el "servidor de correo" son los logs.
    logger.info('SMTP no configurado. Código de reset (solo desarrollo):', {
      email: user.email,
      resetCode: token,
      expiresIn: '15 minutos',
    });
  }
};

/** Restablece la contraseña con el código recibido; cierra todas las sesiones. */
const resetPassword = async (resetToken, newPassword) => {
  const user = await User.findOne({
    resetPasswordToken: sha256(resetToken),
    resetPasswordExpires: { $gt: Date.now() },
  });

  if (!user) {
    throw new ValidationError('Código inválido o expirado. Solicita uno nuevo');
  }

  user.password = newPassword;
  user.resetPasswordToken = null;
  user.resetPasswordExpires = null;
  user.refreshSessions = []; // una sesión robada no sobrevive al reset
  await user.save(); // el pre-save hashea y la validación del schema aplica
  await user.resetLoginAttempts();

  logger.info('Contraseña restablecida', { userId: user._id });
};

module.exports = { requestReset, resetPassword };
