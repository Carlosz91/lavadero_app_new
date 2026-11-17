const { body, param, validationResult } = require('express-validator');
const { ValidationError } = require('../utils/AppError');
const {
  WASH_TYPES,
  CAR_STATUSES,
  PAYMENT_METHODS,
  PAYMENT_STATUSES,
} = require('../config/constants');

const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const details = errors.array().map((e) => ({ field: e.param, message: e.msg }));
    throw new ValidationError('Validación fallida', details);
  }
  next();
};

const validateRegister = [
  body('email').isEmail().withMessage('Email inválido').normalizeEmail().toLowerCase(),
  body('password')
    .isLength({ min: 8 })
    .withMessage('Contraseña mínimo 8 caracteres')
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/)
    .withMessage('Contraseña debe tener mayúscula, minúscula, número y símbolo (@$!%*?&)'),
  body('name')
    .trim()
    .notEmpty()
    .withMessage('Nombre es obligatorio')
    .isLength({ min: 2, max: 50 })
    .withMessage('Nombre debe tener 2-50 caracteres'),
];

const validateLogin = [
  body('email').isEmail().withMessage('Email inválido').normalizeEmail().toLowerCase(),
  body('password').notEmpty().withMessage('Contraseña es obligatoria'),
];

const validateCarRegister = [
  body('plate').trim().notEmpty().withMessage('Placa es obligatoria'),
  body('model').trim().notEmpty().withMessage('Modelo es obligatorio'),
  body('brand').trim().notEmpty().withMessage('Marca es obligatoria'),
  body('washType').isIn(WASH_TYPES).withMessage('Tipo de lavado inválido'),
  body('amount').optional().isFloat({ min: 0.01 }).withMessage('Monto debe ser mayor a 0'),
  body('scheduledDate')
    .optional({ values: 'falsy' })
    .isISO8601()
    .withMessage('Fecha de agendamiento inválida (use YYYY-MM-DD)'),
];

const validateCarStatusUpdate = [
  param('carId').isMongoId().withMessage('ID de vehículo inválido'),
  body('status').isIn(CAR_STATUSES).withMessage('Estado inválido'),
];

const validatePaymentCreate = [
  body('plate').trim().notEmpty().withMessage('Placa es obligatoria'),
  body('method')
    .isIn(PAYMENT_METHODS)
    .withMessage(`Método de pago inválido. Válidos: ${PAYMENT_METHODS.join(', ')}`),
  body('amount').isFloat({ min: 0.01 }).withMessage('Monto debe ser mayor a 0'),
  body('userId').optional().isMongoId().withMessage('userId inválido'),
  body('carId').optional({ values: 'null' }).isMongoId().withMessage('carId inválido'),
];

const validatePaymentStatusUpdate = [
  param('id').isMongoId().withMessage('ID de pago inválido'),
  body('status').isIn(PAYMENT_STATUSES).withMessage('Estado inválido'),
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
    .isLength({ min: 8 })
    .withMessage('Contraseña mínimo 8 caracteres')
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
