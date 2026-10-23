const nodemailer = require('nodemailer');

/**
 * Transport de correo para emails transaccionales (reset de contraseña, etc).
 * Se activa solo si SMTP_HOST y SMTP_USER están definidos en .env.
 * Si no hay SMTP configurado devuelve null y el caller decide el fallback
 * (por ejemplo, mostrar el enlace/código en los logs en desarrollo).
 */
let transporter = null;

if (process.env.SMTP_HOST && process.env.SMTP_USER) {
  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT) || 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth:
      process.env.SMTP_PASS
        ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
        : undefined,
  });
}

const FROM = process.env.SMTP_FROM || process.env.SMTP_USER || 'no-reply@lavadero.local';

/**
 * Bandeja de salida en memoria para desarrollo/tests sin SMTP.
 * Solo se llena fuera de producción; permite verificar el contenido de los
 * emails (p.ej. el código de reset) en los tests.
 */
exports.outbox = [];

/**
 * Envía un email HTML/texto. No lanza: si falla registra y devuelve false.
 * @param {string} to
 * @param {string} subject
 * @param {string} text
 * @param {string} html
 * @returns {Promise<boolean>} true si se envió
 */
exports.sendMail = async (to, subject, text, html) => {
  if (!transporter) {
    if (process.env.NODE_ENV !== 'production') {
      exports.outbox.push({ to, subject, text, html });
    }
    return false;
  }
  try {
    await transporter.sendMail({
      from: `"Lavadero App" <${FROM}>`,
      to,
      subject,
      text,
      html,
    });
    return true;
  } catch (err) {
    require('./logger').error('Error enviando email', { error: err.message, to });
    return false;
  }
};

exports.transporter = transporter;
