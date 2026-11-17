const Payment = require('../models/paymentModel');
const Car = require('../models/carModel');
const User = require('../models/userModel');
const logger = require('../utils/logger');
const { NotFoundError, ValidationError, ForbiddenError } = require('../utils/AppError');
const { PAYMENT_METHODS } = require('../config/constants');

const STAFF_ROLES = ['admin', 'staff'];

/**
 * Registra un pago manual. El pago pertenece al CLIENTE, no a quien lo registra
 * (staff/admin). Orden: userId explícito > dueño del auto indicado > quien registra.
 */
const createPayment = async (actorId, data) => {
  const { plate, method, amount, status, carId, userId: targetUserId } = data;

  let userId = actorId;
  if (targetUserId) {
    if (!(await User.exists({ _id: targetUserId }))) {
      throw new NotFoundError('Usuario');
    }
    userId = targetUserId;
  } else if (carId) {
    const car = await Car.findById(carId).select('userId');
    if (!car) {
      throw new NotFoundError('Vehículo');
    }
    userId = car.userId;
  }

  const payment = await Payment.create({
    userId,
    plate: plate.trim().toUpperCase(),
    method,
    amount,
    status: status || 'Pendiente',
    carId: carId || null,
  });

  logger.info('Pago registrado', { paymentId: payment._id, userId, amount });
  return payment;
};

/** Actualiza estado y/o método de un pago. Solo personal (los usuarios pagan con Stripe). */
const updatePayment = async (actor, id, { status, method }) => {
  const payment = await Payment.findById(id);
  if (!payment) {
    throw new NotFoundError('Pago');
  }

  if (!STAFF_ROLES.includes(actor.role)) {
    throw new ForbiddenError(
      'Solo el personal puede actualizar pagos. Los usuarios pagan en línea mediante Stripe.'
    );
  }

  const updateData = { status };
  if (method) {
    if (!PAYMENT_METHODS.includes(method)) {
      throw new ValidationError(`Método inválido. Válidos: ${PAYMENT_METHODS.join(', ')}`);
    }
    updateData.method = method;
  }

  const updated = await Payment.findByIdAndUpdate(id, updateData, {
    new: true,
    runValidators: true,
  });

  logger.info('Pago actualizado', {
    paymentId: id,
    status,
    method: method || 'sin cambio',
    by: actor.id,
  });
  return updated;
};

module.exports = { createPayment, updatePayment };
