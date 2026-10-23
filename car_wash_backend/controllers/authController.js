const User = require('../models/userModel');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const logger = require('../utils/logger');
const { sendMail } = require('../utils/mailer');
const { AppError, UnauthorizedError, NotFoundError, ValidationError } = require('../utils/AppError');

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET no está definido en variables de entorno');
}

const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;

const generateToken = (userId, role = 'user') => {
  return jwt.sign({ userId, role, type: 'access' }, process.env.JWT_SECRET, { expiresIn: '1h' });
};

const generateRefreshToken = (userId) => {
  return jwt.sign({ userId, type: 'refresh' }, process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET, {
    expiresIn: '7d',
  });
};

/**
 * @desc    Registra usuario. El primer usuario registrado obtiene rol 'admin' automáticamente.
 * @route   POST /api/auth/register
 * @access  Público
 */
exports.registerUser = async (req, res, next) => {
  try {
    const { email, password, name } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      if (!existingUser.password) {
        throw new ValidationError('Esta cuenta está vinculada a Google. Inicia sesión con Google.');
      }
      throw new ValidationError('El correo electrónico ya está registrado');
    }

    const userCount = await User.countDocuments();
    const role = userCount === 0 ? 'admin' : 'user';

    const newUser = new User({ email, password, name, role });
    await newUser.save();

    const token = generateToken(newUser._id, newUser.role);
    const refreshToken = generateRefreshToken(newUser._id);

    logger.info('Usuario registrado', { userId: newUser._id, email });

    res.status(201).json({
      message: 'Usuario registrado exitosamente',
      userId: newUser._id,
      token,
      refreshToken,
      user: {
        id: newUser._id,
        email: newUser.email,
        name: newUser.name,
        role: newUser.role,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Inicia sesión. Verifica bloqueo por fuerza bruta y credenciales.
 * @route   POST /api/auth/login
 * @access  Público
 */
exports.loginUser = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      throw new UnauthorizedError('Credenciales inválidas');
    }

    if (!user.password) {
      throw new UnauthorizedError('Esta cuenta usa Google. Inicia sesión con Google.');
    }

    if (user.isLocked()) {
      const timeLeft = Math.ceil((user.lockUntil - new Date()) / 60000);
      logger.warn('Intento de login en cuenta bloqueada', { userId: user._id });
      throw new AppError(`Cuenta bloqueada. Intenta en ${timeLeft} minutos`, 403, 'ACCOUNT_LOCKED');
    }

    const passwordMatch = await user.comparePassword(password);
    if (!passwordMatch) {
      await user.incLoginAttempts();
      throw new UnauthorizedError('Credenciales inválidas');
    }

    await user.resetLoginAttempts();

    const token = generateToken(user._id, user.role);
    const refreshToken = generateRefreshToken(user._id);

    logger.info('Login exitoso', { userId: user._id });

    res.status(200).json({
      message: 'Inicio de sesión exitoso',
      token,
      refreshToken,
      userId: user._id,
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Renueva el token JWT usando refresh token
 * @route   POST /api/auth/refresh
 * @access  Público (con refresh token)
 */
exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      throw new ValidationError('Refresh token requerido');
    }

    const decoded = jwt.verify(
      refreshToken,
      process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET
    );

    // Solo aceptamos refresh tokens reales: un access token (o un token viejo sin
    // claim type) no puede usarse para renovar sesión.
    if (decoded.type !== 'refresh') {
      throw new UnauthorizedError('Token inválido o expirado');
    }

    const user = await User.findById(decoded.userId);
    if (!user) {
      throw new UnauthorizedError('Usuario no encontrado');
    }

    const newToken = generateToken(user._id, user.role);
    const newRefreshToken = generateRefreshToken(user._id);

    res.status(200).json({ token: newToken, refreshToken: newRefreshToken });
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      return next(new UnauthorizedError('Token inválido o expirado'));
    }
    next(err);
  }
};

/**
 * @desc    Inicia sesión con Google OAuth. Verifica idToken y crea usuario si no existe.
 * @route   POST /api/auth/google
 * @access  Público
 */
exports.googleLogin = async (req, res, next) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      throw new ValidationError('Token de Google requerido');
    }

    const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
    const data = await response.json();

    if (!response.ok || data.error) {
      throw new UnauthorizedError('Token de Google inválido');
    }

    if (!GOOGLE_CLIENT_ID) {
      if (process.env.NODE_ENV === 'production') {
        logger.error('GOOGLE_CLIENT_ID no está configurado en producción');
        throw new AppError('Configuración del servidor incompleta', 500, 'SERVER_CONFIG');
      }
    } else if (data.aud !== GOOGLE_CLIENT_ID) {
      throw new UnauthorizedError('Token de Google no emitido para esta aplicación');
    }

    const googleId = data.sub;
    const email = data.email;
    const name = data.name || email.split('@')[0];

    let user = await User.findOne({ googleId });
    if (!user) {
      user = await User.findOne({ email });
      if (user) {
        user.googleId = googleId;
        await user.save();
      } else {
        const userCount = await User.countDocuments();
        const role = userCount === 0 ? 'admin' : 'user';
        user = new User({ email, name, googleId, role });
        await user.save();
      }
    }

    const token = generateToken(user._id, user.role);
    const refreshToken = generateRefreshToken(user._id);

    logger.info('Login con Google exitoso', { userId: user._id, email });

    res.status(200).json({
      message: 'Inicio de sesión exitoso',
      token,
      refreshToken,
      userId: user._id,
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Cambia la contraseña del usuario autenticado
 * @route   PUT /api/auth/change-password
 * @access  Private
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id;

    if (!currentPassword || !newPassword) {
      throw new ValidationError('Contraseñas son obligatorias');
    }

    if (!PASSWORD_REGEX.test(newPassword)) {
      throw new ValidationError(
        'La nueva contraseña debe tener mínimo 8 caracteres, mayúscula, minúscula, número y símbolo (@$!%*?&)'
      );
    }

    if (currentPassword === newPassword) {
      throw new ValidationError('La nueva contraseña debe ser diferente a la actual');
    }

    const user = await User.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario');
    }

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      throw new UnauthorizedError('Contraseña actual incorrecta');
    }

    user.password = newPassword;
    await user.save();

    logger.info('Contraseña cambiada', { userId });

    res.status(200).json({ message: 'Contraseña actualizada exitosamente' });
  } catch (err) {
    next(err);
  }
};

/**
 * Genera un token de reset a partir de bytes aleatorios y guarda su hash sha256
 * en el usuario. El token plano nunca toca la base de datos.
 */
const issueResetToken = async (user) => {
  const token = crypto.randomBytes(32).toString('hex');
  user.resetPasswordToken = crypto.createHash('sha256').update(token).digest('hex');
  user.resetPasswordExpires = Date.now() + 15 * 60 * 1000; // 15 minutos
  await user.save();
  return token;
};

const resetEmailTemplate = (link, code) => `
  <p>Hola,</p>
  <p>Recibimos una solicitud para restablecer tu contraseña en Lavadero App.</p>
  <p><a href="${link}">Restablecer contraseña</a></p>
  <p>O copia este código en la app:</p>
  <p style="font-size:18px;font-weight:bold;letter-spacing:1px">${code}</p>
  <p>Si no fuiste tú, ignora este correo.</p>
  <p style="color:#888">El código expira en 15 minutos.</p>
`;

const resetTextTemplate = (code) =>
  `Recibimos una solicitud para restablecer tu contraseña en Lavadero App.\n\n` +
  `Código: ${code}\n\n` +
  `Ingresa este código en la app (o usa el enlace del correo si lo incluye).\n` +
  `El código expira en 15 minutos. Si no fuiste tú, ignora este correo.`;

/**
 * @desc    Solicita reset de contraseña. Envía el código por email (SMTP) o
 *          lo muestra en logs solo en desarrollo sin SMTP.
 * @route   POST /api/auth/forgot-password
 * @access  Público
 */
exports.forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;

    // Respuesta genérica: no filtramos si el email existe (previene enumeración).
    const generic = { message: 'Si el correo está registrado, enviaremos instrucciones para restablecer la contraseña' };

    const user = await User.findOne({ email });
    if (!user || !user.password) {
      // Cuentas de Google no tienen contraseña local: nada que resetear por este vía.
      return res.status(200).json(generic);
    }

    const token = await issueResetToken(user);

    const frontendBase = process.env.APP_RESET_URL; // opcional: URL web de reset
    const link = frontendBase
      ? `${frontendBase.replace(/\/$/, '')}?token=${token}`
      : `http://localhost:3000/reset-password?token=${token}`;

    const sent = await sendMail(
      user.email,
      'Restablecer contraseña - Lavadero App',
      resetTextTemplate(token),
      resetEmailTemplate(link, token)
    );

    if (!sent) {
      if (process.env.NODE_ENV === 'production') {
        logger.warn('SMTP no configurado en producción: no se pudo enviar el email de reset', { userId: user._id });
      } else {
        // Fallback de desarrollo: el "servidor de correo" son los logs.
        logger.info('SMTP no configurado. Código de reset (solo desarrollo):', {
          email: user.email,
          resetCode: token,
          expiresIn: '15 minutos',
        });
      }
    } else {
      logger.info('Email de reset enviado', { userId: user._id });
    }

    res.status(200).json(generic);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Restablece la contraseña usando el código recibido por email
 * @route   POST /api/auth/reset-password
 * @access  Público
 */
exports.resetPassword = async (req, res, next) => {
  try {
    const { resetToken, newPassword } = req.body;

    const hashed = crypto.createHash('sha256').update(resetToken).digest('hex');
    const user = await User.findOne({
      resetPasswordToken: hashed,
      resetPasswordExpires: { $gt: Date.now() },
    });

    if (!user) {
      throw new ValidationError('Código inválido o expirado. Solicita uno nuevo');
    }

    user.password = newPassword;
    user.resetPasswordToken = null;
    user.resetPasswordExpires = null;
    await user.save(); // el pre-save hashea y la validación del schema aplica
    await user.resetLoginAttempts();

    logger.info('Contraseña restablecida', { userId: user._id });

    res.status(200).json({ message: 'Contraseña restablecida exitosamente. Ya puedes iniciar sesión' });
  } catch (err) {
    next(err);
  }
};
