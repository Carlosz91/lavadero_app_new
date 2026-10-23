const { body, param, validationResult } = require('express-validator');
const { ValidationError } = require('../utils/AppError');

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const details = errors.array().map(e => ({ field: e.param, message: e.msg }));
    throw new ValidationError('Validación fallida', details);
  }
  next();
};

const validateRegister = [
  body('email')
    .isEmail().withMessage('Email inválido')
    .normalizeEmail().toLowerCase(),
  body('password')
    .isLength({ min: 8 }).withMessage('Contraseña mínimo 8 caracteres')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/)
    .withMessage('Contraseña debe tener mayúscula, minúscula, número y símbolo (@$!%*?&)'),
  body('name')
    .trim().notEmpty().withMessage('Nombre es obligatorio')
    .isLength({ min: 2, max: 50 }).withMessage('Nombre debe tener 2-50 caracteres'),
];

const validateLogin = [
  body('email').isEmail().withMessage('Email inválido').normalizeEmail().toLowerCase(),
  body('password').notEmpty().withMessage('Contraseña es obligatoria'),
];

const validateCarRegister = [
  body('plate').trim().notEmpty().withMessage('Placa es obligatoria'),
  body('model').trim().notEmpty().withMessage('Modelo es obligatorio'),
  body('brand').trim().notEmpty().withMessage('Marca es obligatoria'),
  body('washType')
    .isIn(['Básico', 'Premium', 'Premium Plus', 'Completo', 'Detailing', 'Full Package'])
    .withMessage('Tipo de lavado inválido'),
  body('amount').optional().isFloat({ min: 0.01 }).withMessage('Monto debe ser mayor a 0'),
];

const validateCarStatusUpdate = [
  param('carId').isMongoId().withMessage('ID de vehículo inválido'),
  body('status')
    .isIn(['Pendiente', 'En Progreso', 'Completado', 'Cancelado'])
    .withMessage('Estado inválido'),
];

const VALID_METHODS = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago', 'Stripe', 'Otro'];

const validatePaymentCreate = [
  body('plate').trim().notEmpty().withMessage('Placa es obligatoria'),
  body('method')
    .isIn(VALID_METHODS)
    .withMessage(`Método de pago inválido. Válidos: ${VALID_METHODS.join(', ')}`),
  body('amount').isFloat({ min: 0.01 }).withMessage('Monto debe ser mayor a 0'),
];

const validatePaymentStatusUpdate = [
  param('id').isMongoId().withMessage('ID de pago inválido'),
  body('status')
    .isIn(['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'])
    .withMessage('Estado inválido'),
];

const validateMongoId = (field = 'id') => [
  param(field).isMongoId().withMessage(`ID de ${field} inválido`),
];

const validateForgotPassword = [
  body('email').isEmail().withMessage('Email inválido').normalizeEmail().toLowerCase(),
];

const validateResetPassword = [
  body('resetToken').notEmpty().withMessage('Código de restablecimiento requerido'),
  body('newPassword')
    .isLength({ min: 8 }).withMessage('Contraseña mínimo 8 caracteres')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/)
    .withMessage('Contraseña debe tener mayúscula, minúscula, número y símbolo (@$!%*?&)'),
];

module.exports = {
  handleValidationErrors,
  validateRegister,
  validateLogin,
  validateCarRegister,
  validateCarStatusUpdate,
  validatePaymentCreate,
  validatePaymentStatusUpdate,
  validateMongoId,
  validateForgotPassword,
  validateResetPassword,
};
