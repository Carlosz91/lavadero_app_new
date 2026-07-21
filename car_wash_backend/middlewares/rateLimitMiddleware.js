const rateLimit = require('express-rate-limit');

const isTest = () => process.env.NODE_ENV === 'test';

exports.globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: isTest() ? 0 : 100,
  message: 'Demasiadas solicitudes desde esta dirección IP, intenta más tarde',
  standardHeaders: true,
  legacyHeaders: false,
  skip: isTest,
});

exports.authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  skipSuccessfulRequests: true,
  message: 'Demasiados intentos de inicio de sesión, intenta en 15 minutos',
  skip: isTest,
});

exports.registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: isTest() ? 0 : 3,
  message: 'Demasiados registros desde esta dirección IP',
  skip: isTest,
});
