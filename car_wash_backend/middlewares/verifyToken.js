const jwt = require('jsonwebtoken');
const { UnauthorizedError, ForbiddenError } = require('../utils/AppError');

const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    throw new UnauthorizedError('No autorizado');
  }

  const token = authHeader.split(' ')[1];
  if (!token) {
    throw new UnauthorizedError('Token faltante');
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: decoded.userId, role: decoded.role || 'user' };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      throw new UnauthorizedError('Token expirado');
    }
    throw new UnauthorizedError('Token inválido');
  }
};

const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      throw new ForbiddenError('No tienes permiso para realizar esta acción');
    }
    next();
  };
};

module.exports = verifyToken;
module.exports.requireRole = requireRole;
