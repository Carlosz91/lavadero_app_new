// Monitoreo de errores opcional (Sentry). Sin SENTRY_DSN no hace nada y
// @sentry/node ni siquiera se carga.
const logger = require('./logger');

let sentry = null;

const init = () => {
  if (!process.env.SENTRY_DSN) return false;
  try {
    sentry = require('@sentry/node');
    sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.NODE_ENV || 'development',
      release: process.env.APP_VERSION,
      tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE || 0),
      // Nunca enviar cabeceras ni cuerpos (contienen tokens y contraseñas).
      sendDefaultPii: false,
    });
    logger.info('Sentry inicializado');
    return true;
  } catch (err) {
    sentry = null;
    logger.warn('SENTRY_DSN definido pero @sentry/node no está disponible', { error: err.message });
    return false;
  }
};

const captureException = (err, context = {}) => {
  if (!sentry) return;
  try {
    sentry.withScope((scope) => {
      Object.entries(context).forEach(([k, v]) => scope.setTag(k, String(v)));
      sentry.captureException(err);
    });
  } catch (_) {
    // el monitoreo nunca debe romper una petición
  }
};

const flush = async (timeoutMs = 2000) => {
  if (sentry) await sentry.flush(timeoutMs).catch(() => {});
};

module.exports = { init, captureException, flush };
