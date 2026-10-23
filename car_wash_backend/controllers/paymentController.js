const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { NotFoundError, ValidationError, ForbiddenError } = require('../utils/AppError');

const VALID_METHODS = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago', 'Stripe', 'Otro'];
const VALID_STATUSES = ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'];

/**
 * @desc    Registra un pago manual
 * @route   POST /api/payments
 * @access  Private
 */
exports.createPayment = async (req, res, next) => {
  try {
    const { plate, method, amount, status, carId } = req.body;
    const userId = req.user.id;

    const newPayment = new Payment({
      userId,
      plate: plate.trim().toUpperCase(),
      method,
      amount,
      status: status || 'Pendiente',
      carId: carId || null,
    });

    await newPayment.save();

    logger.info('Pago registrado', { paymentId: newPayment._id, userId, amount });

    res.status(201).json(newPayment);
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
    if (status && ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'].includes(status)) {
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
    const { id } = req.params;
    const { status, method } = req.body;

    const payment = await Payment.findById(id);
    if (!payment) {
      throw new NotFoundError('Pago');
    }

    const isStaff = ['admin', 'staff'].includes(req.user.role);
    if (!isStaff) {
      throw new ForbiddenError(
        'Solo el personal puede actualizar pagos. Los usuarios pagan en línea mediante Stripe.'
      );
    }

    const updateData = { status };
    if (method) {
      if (!VALID_METHODS.includes(method)) {
        throw new ValidationError(`Método inválido. Válidos: ${VALID_METHODS.join(', ')}`);
      }
      updateData.method = method;
    }

    const updatedPayment = await Payment.findByIdAndUpdate(
      id,
      updateData,
      { new: true, runValidators: true }
    );

    logger.info('Pago actualizado', { paymentId: id, status, method: method || 'sin cambio', by: req.user.id });

    res.status(200).json(updatedPayment);
  } catch (err) {
    next(err);
  }
};
