const User = require('../models/userModel');
const logger = require('../utils/logger');
const {
  AppError,
  UnauthorizedError,
  NotFoundError,
  ValidationError,
} = require('../utils/AppError');
const {
  generateToken,
  generateRefreshToken,
  rotateRefreshToken,
  revokeAllSessions,
  revokeSession,
  initialRole,
} = require('../services/tokenService');
const { verifyIdToken } = require('../services/googleAuthService');
const { requestReset, resetPassword } = require('../services/passwordResetService');

const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;

/**
 * @desc    Registra usuario. Fuera de producción el primero es 'admin'; en producción el admin se crea con `npm run create-admin`.
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

    const role = await initialRole();

    const newUser = new User({ email, password, name, role });
    await newUser.save();

    const token = generateToken(newUser._id, newUser.role);
    const refreshToken = await generateRefreshToken(newUser._id);

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
    const refreshToken = await generateRefreshToken(user._id);

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
    const tokens = await rotateRefreshToken(refreshToken);
    res.status(200).json(tokens);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Cierra la sesión: revoca el refresh token enviado (o todos con all=true)
 * @route   POST /api/auth/logout
 * @access  Private
 */
exports.logout = async (req, res, next) => {
  try {
    const { refreshToken, all } = req.body || {};
    if (all === true) {
      await revokeAllSessions(req.user.id);
    } else if (refreshToken) {
      await revokeSession(req.user.id, refreshToken);
    }
    res.status(200).json({ message: 'Sesión cerrada' });
  } catch (err) {
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
    const { googleId, email, name } = await verifyIdToken(req.body.idToken);

    let user = await User.findOne({ googleId });
    if (!user) {
      user = await User.findOne({ email });
      if (user) {
        user.googleId = googleId;
        await user.save();
      } else {
        user = new User({ email, name, googleId, role: await initialRole() });
        await user.save();
      }
    }

    const token = generateToken(user._id, user.role);
    const refreshToken = await generateRefreshToken(user._id);

    logger.info('Login con Google exitoso', { userId: user._id, email });

    res.status(200).json({
      message: 'Inicio de sesión exitoso',
      token,
      refreshToken,
      userId: user._id,
      user: { id: user._id, email: user.email, name: user.name, role: user.role },
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
    user.refreshSessions = []; // cierra sesiones en otros dispositivos
    await user.save();

    logger.info('Contraseña cambiada', { userId });

    res.status(200).json({ message: 'Contraseña actualizada exitosamente' });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Solicita reset de contraseña. Envía el código por email (SMTP) o
 *          lo muestra en logs solo en desarrollo sin SMTP.
 * @route   POST /api/auth/forgot-password
 * @access  Público
 */
exports.forgotPassword = async (req, res, next) => {
  try {
    await requestReset(req.body.email);
    // Respuesta genérica: no filtramos si el email existe (previene enumeración).
    res.status(200).json({
      message:
        'Si el correo está registrado, enviaremos instrucciones para restablecer la contraseña',
    });
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
    await resetPassword(req.body.resetToken, req.body.newPassword);
    res
      .status(200)
      .json({ message: 'Contraseña restablecida exitosamente. Ya puedes iniciar sesión' });
  } catch (err) {
    next(err);
  }
};
