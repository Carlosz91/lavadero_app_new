const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/userModel');
const logger = require('../utils/logger');
const { UnauthorizedError } = require('../utils/AppError');

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET no está definido en variables de entorno');
}
// En producción el refresh token DEBE firmarse con un secreto distinto al del access.
if (process.env.NODE_ENV === 'production' && !process.env.JWT_REFRESH_SECRET) {
  throw new Error('JWT_REFRESH_SECRET es obligatorio en producción');
}

const ACCESS_TOKEN_TTL = process.env.ACCESS_TOKEN_TTL || '5m';
const REFRESH_TOKEN_TTL_DAYS = 7;
const MAX_SESSIONS_PER_USER = 5; // dispositivos simultáneos

const refreshSecret = () => process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET;
const sha256 = (v) => crypto.createHash('sha256').update(v).digest('hex');

const generateToken = (userId, role = 'user') =>
  jwt.sign({ userId, role, type: 'access' }, process.env.JWT_SECRET, {
    expiresIn: ACCESS_TOKEN_TTL,
  });

/**
 * Emite un refresh token con jti único y registra su hash en el usuario.
 * Solo el hash del jti se guarda; un token es válido únicamente si su jti está
 * registrado, lo que permite rotarlo (un solo uso) y revocarlo.
 */
const generateRefreshToken = async (userId) => {
  const jti = crypto.randomBytes(16).toString('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
  await User.updateOne(
    { _id: userId },
    {
      $push: {
        refreshSessions: {
          $each: [{ jtiHash: sha256(jti), expiresAt }],
          $slice: -MAX_SESSIONS_PER_USER,
        },
      },
    }
  );
  return jwt.sign({ userId, type: 'refresh', jti }, refreshSecret(), {
    expiresIn: `${REFRESH_TOKEN_TTL_DAYS}d`,
  });
};

const revokeAllSessions = (userId) =>
  User.updateOne({ _id: userId }, { $set: { refreshSessions: [] } });

/** Revoca una sola sesión (logout). Un token inválido o ajeno se ignora. */
const revokeSession = async (userId, refreshToken) => {
  try {
    const decoded = jwt.verify(refreshToken, refreshSecret());
    if (decoded.jti && String(decoded.userId) === String(userId)) {
      await User.updateOne(
        { _id: userId },
        { $pull: { refreshSessions: { jtiHash: sha256(decoded.jti) } } }
      );
    }
  } catch (_) {
    // token ya inválido/expirado: nada que revocar
  }
};

/**
 * Rota un refresh token: lo valida, lo consume (un solo uso) y emite un par nuevo.
 * Si el jti ya no existe, el token fue usado antes (posible robo): se cierran
 * TODAS las sesiones del usuario.
 * @returns {Promise<{ token: string, refreshToken: string }>}
 */
const rotateRefreshToken = async (refreshToken) => {
  let decoded;
  try {
    decoded = jwt.verify(refreshToken, refreshSecret());
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      throw new UnauthorizedError('Token inválido o expirado');
    }
    throw err;
  }

  // Un access token (o un token viejo sin claim type/jti) no puede renovar sesión.
  if (decoded.type !== 'refresh' || !decoded.jti) {
    throw new UnauthorizedError('Token inválido o expirado');
  }

  const user = await User.findOneAndUpdate(
    { _id: decoded.userId, 'refreshSessions.jtiHash': sha256(decoded.jti) },
    { $pull: { refreshSessions: { jtiHash: sha256(decoded.jti) } } }
  );
  if (!user) {
    await revokeAllSessions(decoded.userId);
    logger.warn('Refresh token reutilizado o revocado: sesiones cerradas', {
      userId: decoded.userId,
    });
    throw new UnauthorizedError('Token inválido o expirado');
  }

  return {
    token: generateToken(user._id, user.role),
    refreshToken: await generateRefreshToken(user._id),
  };
};

/**
 * Rol inicial de un usuario nuevo. En producción NUNCA se asigna admin
 * automáticamente (cualquiera podría registrarse primero y quedarse con el
 * sistema): el admin se crea con `npm run create-admin`. En desarrollo/test se
 * mantiene la comodidad de que el primer usuario sea admin.
 */
const initialRole = async () => {
  if (process.env.NODE_ENV === 'production') return 'user';
  return (await User.countDocuments()) === 0 ? 'admin' : 'user';
};

module.exports = {
  ACCESS_TOKEN_TTL,
  generateToken,
  generateRefreshToken,
  rotateRefreshToken,
  revokeAllSessions,
  revokeSession,
  initialRole,
};
