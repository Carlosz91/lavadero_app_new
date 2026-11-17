const crypto = require('crypto');
const Idempotency = require('../models/idempotencyModel');
const { ValidationError, AppError } = require('../utils/AppError');

const PROCESSING_STATUS = 202;

// Huella de la petición: método + ruta + cuerpo. La misma clave solo puede
// repetir EXACTAMENTE la misma operación.
const fingerprintOf = (req) =>
  crypto
    .createHash('sha256')
    .update(`${req.method}|${req.baseUrl}${req.path}|${JSON.stringify(req.body || {})}`)
    .digest('hex');

const replay = (res, doc) => res.status(doc.response.status).json(doc.response.body);

const idempotencyMiddleware = async (req, res, next) => {
  const key = req.headers['idempotency-key'];
  if (!key) {
    return next(new ValidationError('Idempotency-Key header requerido'));
  }
  if (key.length > 128) {
    return next(new ValidationError('Idempotency-Key demasiado larga (máx. 128 caracteres)'));
  }
  if (!req.user || !req.user.id) {
    // Debe ir después de verifyToken: la clave se acota por usuario.
    return next(new AppError('Idempotencia requiere usuario autenticado', 500, 'SERVER_CONFIG'));
  }

  const userId = String(req.user.id);
  const fingerprint = fingerprintOf(req);

  // Una respuesta guardada solo se reutiliza si es del mismo usuario y la misma petición.
  const check = (doc) => {
    if (doc.fingerprint !== fingerprint) {
      return new AppError(
        'Idempotency-Key ya usada con una petición distinta',
        422,
        'IDEMPOTENCY_KEY_REUSED'
      );
    }
    if (doc.response.status === PROCESSING_STATUS) {
      return new AppError('Solicitud duplicada en proceso', 409, 'DUPLICATE_REQUEST');
    }
    return null;
  };

  try {
    const existing = await Idempotency.findOne({ userId, key });
    if (existing) {
      const err = check(existing);
      return err ? next(err) : replay(res, existing);
    }

    // Lock atómico: el índice único {userId, key} evita que dos requests concurrentes procesen.
    try {
      await Idempotency.create({
        key,
        userId,
        fingerprint,
        response: { status: PROCESSING_STATUS, body: {} },
      });
    } catch (err) {
      if (err.code === 11000) {
        const concurrent = await Idempotency.findOne({ userId, key });
        if (!concurrent)
          return next(new AppError('Solicitud duplicada en proceso', 409, 'DUPLICATE_REQUEST'));
        const e = check(concurrent);
        return e ? next(e) : replay(res, concurrent);
      }
      throw err;
    }

    const originalJson = res.json.bind(res);
    res.json = function (body) {
      // Solo se conservan las respuestas exitosas. Un error (validación, 5xx) libera
      // la clave: así se puede reintentar corrigiendo la petición, y un fallo no
      // deja la clave atascada ni cachea el error 24h.
      const op =
        res.statusCode >= 400
          ? Idempotency.deleteOne({ userId, key })
          : Idempotency.updateOne(
              { userId, key },
              { $set: { response: { status: res.statusCode, body } } }
            );
      op.catch(() => {});
      return originalJson(body);
    };

    next();
  } catch (err) {
    next(err);
  }
};

module.exports = idempotencyMiddleware;
