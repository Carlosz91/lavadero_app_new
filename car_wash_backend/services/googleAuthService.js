const logger = require('../utils/logger');
const { AppError, UnauthorizedError, ValidationError } = require('../utils/AppError');

/**
 * Verifica un idToken de Google contra el endpoint tokeninfo y devuelve la
 * identidad. Exige audiencia correcta y correo verificado (sin esto se podría
 * vincular una cuenta existente con un email que el atacante no controla).
 * @returns {Promise<{ googleId: string, email: string, name: string }>}
 */
const verifyIdToken = async (idToken) => {
  if (!idToken) {
    throw new ValidationError('Token de Google requerido');
  }

  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
  );
  const data = await response.json();

  if (!response.ok || data.error) {
    throw new UnauthorizedError('Token de Google inválido');
  }

  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) {
    if (process.env.NODE_ENV === 'production') {
      logger.error('GOOGLE_CLIENT_ID no está configurado en producción');
      throw new AppError('Configuración del servidor incompleta', 500, 'SERVER_CONFIG');
    }
  } else if (data.aud !== clientId) {
    throw new UnauthorizedError('Token de Google no emitido para esta aplicación');
  }

  if (data.email_verified !== true && data.email_verified !== 'true') {
    throw new UnauthorizedError('El correo de Google no está verificado');
  }

  return {
    googleId: data.sub,
    email: data.email,
    name: data.name || data.email.split('@')[0],
  };
};

module.exports = { verifyIdToken };
