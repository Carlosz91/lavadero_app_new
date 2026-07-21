const User = require('../models/userModel');
const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');
const { AppError, UnauthorizedError, NotFoundError, ValidationError } = require('../utils/AppError');

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET no está definido en variables de entorno');
}

const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;

const generateToken = (userId, role = 'user') => {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET, { expiresIn: '1h' });
};

const generateRefreshToken = (userId) => {
  return jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET, {
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
