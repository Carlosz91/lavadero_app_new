const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');

const isTest = () => process.env.NODE_ENV === 'test';

// En entorno local/dev una sola IP ejecuta decenas de peticiones (Playwright, seeders).
// RATE_LIMIT_MAX eleva todos los limites de peticion sin tocar produccion.
const devMax = (fallback) => {
  const override = Number(process.env.RATE_LIMIT_MAX ?? 0);
  return override > 0 ? override : fallback;
};

exports.globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: isTest() ? 0 : devMax(100),
  message: 'Demasiadas solicitudes desde esta dirección IP, intenta más tarde',
  standardHeaders: true,
  legacyHeaders: false,
  skip: isTest,
});

exports.authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: devMax(5),
  skipSuccessfulRequests: true,
  message: 'Demasiados intentos de inicio de sesión, intenta en 15 minutos',
  skip: isTest,
});

exports.registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: isTest() ? 0 : devMax(3),
  message: 'Demasiados registros desde esta dirección IP',
  skip: isTest,
});

exports.carRegisterLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: isTest() ? 0 : devMax(10),
  message: 'Demasiados vehículos registrados, intenta más tarde',
  skip: isTest,
  keyGenerator: (req) => (req.user ? `user:${req.user.id}` : ipKeyGenerator()(req)),
});
