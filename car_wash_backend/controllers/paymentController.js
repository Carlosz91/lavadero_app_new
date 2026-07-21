const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { NotFoundError, ValidationError, ForbiddenError } = require('../utils/AppError');

const VALID_METHODS = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago', 'Stripe', 'Otro'];
const VALID_STATUSES = ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'];

exports.createPayment = async (req, res, next) => {
  try {
    const { plate, method, amount, status, carId } = req.body;
    const userId = req.user.id;

    if (!plate || !method || amount == null) {
      throw new ValidationError('Faltan datos requeridos: plate, method, amount');
    }

    if (!VALID_METHODS.includes(method)) {
      throw new ValidationError(`Método inválido. Válidos: ${VALID_METHODS.join(', ')}`);
    }

    if (status && !VALID_STATUSES.includes(status)) {
      throw new ValidationError(`Estado inválido. Válidos: ${VALID_STATUSES.join(', ')}`);
    }

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

exports.getPaymentsAuthenticated = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const { status } = req.query;
    const filter = { userId };
    if (status && ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'].includes(status)) {
      filter.status = status;
    }
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
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

exports.getPaymentsByUserId = async (req, res, next) => {
  try {
    const { userId } = req.params;

    if (req.user.id !== userId && req.user.role !== 'admin') {
      throw new ForbiddenError('No tienes permiso para ver estos pagos');
    }

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
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

exports.updatePaymentStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, method } = req.body;

    if (!status) {
      throw new ValidationError('El estado es requerido');
    }

    if (!VALID_STATUSES.includes(status)) {
      throw new ValidationError(`Estado inválido. Válidos: ${VALID_STATUSES.join(', ')}`);
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

    if (!updatedPayment) {
      throw new NotFoundError('Pago');
    }

    logger.info('Pago actualizado', { paymentId: id, status, method: method || 'sin cambio' });

    res.status(200).json(updatedPayment);
  } catch (err) {
    next(err);
  }
};
