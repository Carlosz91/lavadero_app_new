const Idempotency = require('../models/idempotencyModel');
const { ValidationError, AppError } = require('../utils/AppError');

const PROCESSING_STATUS = 202;

const idempotencyMiddleware = async (req, res, next) => {
  const key = req.headers['idempotency-key'];
  if (!key) {
    return next(new ValidationError('Idempotency-Key header requerido'));
  }

  try {
    const existing = await Idempotency.findOne({ key });
    if (existing) {
      if (existing.response.status === PROCESSING_STATUS) {
        return next(new AppError('Solicitud duplicada en proceso', 409, 'DUPLICATE_REQUEST'));
      }
      return res.status(existing.response.status).json(existing.response.body);
    }

    // Lock atómico: el índice único evita que dos requests concurrentes con la misma key procesen
    try {
      await Idempotency.create({ key, response: { status: PROCESSING_STATUS, body: {} } });
    } catch (err) {
      if (err.code === 11000) {
        const concurrent = await Idempotency.findOne({ key });
        if (concurrent && concurrent.response.status !== PROCESSING_STATUS) {
          return res.status(concurrent.response.status).json(concurrent.response.body);
        }
        return next(new AppError('Solicitud duplicada en proceso', 409, 'DUPLICATE_REQUEST'));
      }
      throw err;
    }

    const originalJson = res.json.bind(res);
    res.json = function (body) {
      Idempotency.updateOne(
        { key },
        { $set: { response: { status: res.statusCode, body } } }
      ).catch(() => {});
      return originalJson(body);
    };

    next();
  } catch (err) {
    next(err);
  }
};

module.exports = idempotencyMiddleware;
