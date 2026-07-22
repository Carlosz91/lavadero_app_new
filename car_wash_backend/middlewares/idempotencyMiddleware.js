const Idempotency = require('../models/idempotencyModel');
const { ValidationError } = require('../utils/AppError');

const idempotencyMiddleware = async (req, res, next) => {
  const key = req.headers['idempotency-key'];
  if (!key) {
    return next(new ValidationError('Idempotency-Key header requerido'));
  }

  try {
    const existing = await Idempotency.findOne({ key });
    if (existing) {
      return res.status(existing.response.status).json(existing.response.body);
    }

    const originalJson = res.json.bind(res);
    res.json = function (body) {
      Idempotency.create({
        key,
        response: { status: res.statusCode, body },
      }).catch(() => {});
      return originalJson(body);
    };

    next();
  } catch (err) {
    next(err);
  }
};

module.exports = idempotencyMiddleware;
