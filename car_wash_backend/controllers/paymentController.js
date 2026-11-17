const Payment = require('../models/paymentModel');
const paymentService = require('../services/paymentService');
const { ForbiddenError } = require('../utils/AppError');

const { PAYMENT_STATUSES: VALID_STATUSES } = require('../config/constants');

/**
 * @desc    Registra un pago manual
 * @route   POST /api/payments
 * @access  Private
 */
exports.createPayment = async (req, res, next) => {
  try {
    const payment = await paymentService.createPayment(req.user.id, req.body);
    res.status(201).json(payment);
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Obtiene pagos del usuario autenticado con paginación y filtro por status
 * @route   GET /api/payments
 * @access  Private
 */
exports.getPaymentsAuthenticated = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;
    const filter = { userId };
    if (status && VALID_STATUSES.includes(status)) {
      filter.status = status;
    }
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [payments, total] = await Promise.all([
      Payment.find(filter).sort({ date: -1 }).skip(skip).limit(limit),
      Payment.countDocuments(filter),
    ]);

    res.status(200).json({
      data: payments,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Obtiene pagos de un usuario específico (admin)
 * @route   GET /api/payments/user/:userId
 * @access  Private (admin)
 */
exports.getPaymentsByUserId = async (req, res, next) => {
  try {
    const { userId } = req.params;

    if (req.user.id !== userId && req.user.role !== 'admin') {
      throw new ForbiddenError('No tienes permiso para ver estos pagos');
    }

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [payments, total] = await Promise.all([
      Payment.find({ userId }).sort({ date: -1 }).skip(skip).limit(limit),
      Payment.countDocuments({ userId }),
    ]);

    res.status(200).json({
      data: payments,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Actualiza estado y/o método de un pago
 * @route   PUT /api/payments/:id
 * @access  Private (admin, staff)
 */
exports.updatePaymentStatus = async (req, res, next) => {
  try {
    const payment = await paymentService.updatePayment(req.user, req.params.id, req.body);
    res.status(200).json(payment);
  } catch (err) {
    next(err);
  }
};
