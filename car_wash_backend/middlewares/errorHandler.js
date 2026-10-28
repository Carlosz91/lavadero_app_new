const logger = require('../utils/logger');
const { AppError } = require('../utils/AppError');

const errorHandler = (err, req, res, _next) => {
  if (err instanceof AppError) {
    logger.warn(`${err.code}: ${err.message}`, {
      requestId: req.id,
      statusCode: err.statusCode,
      path: req.path,
      method: req.method,
      ...(err.details && { details: err.details }),
    });

    return res.status(err.statusCode).json({
      error: err.message,
      code: err.code,
      ...(err.details && { details: err.details }),
    });
  }

  if (err.name === 'ValidationError' && err.errors) {
    const details = Object.values(err.errors).map(e => ({
      field: e.path,
      message: e.message,
    }));
    logger.warn('Mongoose validation error', { requestId: req.id, details, path: req.path });
    return res.status(400).json({ error: 'Datos inválidos', code: 'VALIDATION_ERROR', details });
  }

  if (err.code === 11000) {
    logger.warn('Duplicate key error', { requestId: req.id, path: req.path });
    return res.status(409).json({ error: 'El recurso ya existe', code: 'DUPLICATE_KEY' });
  }

  if (err.name === 'CastError') {
    logger.warn('Cast error', { requestId: req.id, path: req.path, value: err.value });
    return res.status(400).json({ error: 'ID inválido', code: 'INVALID_ID' });
  }

  // JSON mal formado (express.json) o body demasiado grande. No son fallos
  // internos: se responden como error del cliente y se registran como warning.
  if (err.type === 'entity.parse.failed') {
    logger.warn('JSON inválido en la solicitud', {
      requestId: req.id,
      path: req.path,
      method: req.method,
    });
    return res.status(400).json({
      error: 'El cuerpo de la solicitud no es un JSON válido',
      code: 'INVALID_JSON',
    });
  }

  if (err.type === 'entity.too.large') {
    logger.warn('Solicitud demasiado grande', {
      requestId: req.id,
      path: req.path,
      method: req.method,
    });
    return res.status(413).json({
      error: 'La solicitud es demasiado grande',
      code: 'PAYLOAD_TOO_LARGE',
    });
  }

  logger.error('Error no manejado', {
    requestId: req.id,
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  const message = process.env.NODE_ENV === 'production'
    ? 'Error interno del servidor'
    : err.message;

  res.status(err.status || 500).json({
    error: message,
    code: 'INTERNAL_ERROR',
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
};

module.exports = errorHandler;
