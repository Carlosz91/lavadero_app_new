const Car = require('../models/carModel');
const User = require('../models/userModel');
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');
const { NotFoundError, ValidationError } = require('../utils/AppError');
const { getPriceForWashType } = require('../config/priceCatalog');
const { CAR_TRANSITIONS } = require('../config/constants');
const capacity = require('./capacityService');

/**
 * Registra un vehículo: precio del catálogo (nunca del cliente), sin deuda
 * pendiente y con cupo diario reservado de forma atómica.
 */
const registerCar = async (userId, data) => {
  const { plate, model, brand, color, washType, scheduledDate, scheduledTime } = data;

  const serverPrice = getPriceForWashType(washType);
  if (serverPrice === null) {
    throw new ValidationError('Tipo de lavado inválido');
  }

  const pendingPaymentCount = await Payment.countDocuments({ userId, status: 'Pendiente' });
  if (pendingPaymentCount > 0) {
    throw new ValidationError('Tenés un pago pendiente. Pagalo antes de registrar otro vehículo.');
  }

  if (!(await User.exists({ _id: userId }))) {
    throw new NotFoundError('Usuario');
  }

  // Cupo diario: reserva atómica (evita pasarse del límite con requests simultáneos).
  let capacityKey = null;
  if (scheduledDate) {
    capacityKey = capacity.dayKey(scheduledDate);
    if (!capacityKey) {
      throw new ValidationError('Fecha de agendamiento inválida');
    }
    if (!(await capacity.reserveSlot(capacityKey))) {
      throw new ValidationError('Capacidad completa para esta fecha. Elige otro día.');
    }
  }

  const car = new Car({
    capacityKey,
    plate: plate.trim().toUpperCase(),
    model: model.trim(),
    brand: brand.trim(),
    color: color ? String(color).trim() : undefined,
    washType,
    amount: serverPrice,
    scheduledDate: scheduledDate || undefined,
    scheduledTime: scheduledTime || undefined,
    userId,
  });

  try {
    await car.save();
  } catch (err) {
    await capacity.releaseSlot(capacityKey); // no dejar el cupo ocupado si falló el guardado
    throw err;
  }

  logger.info('Vehículo registrado', { carId: car._id, userId, plate });
  return car;
};

/** Cambia el estado validando la transición; cancelar libera el cupo del día. */
const changeStatus = async (carId, status) => {
  const car = await Car.findById(carId);
  if (!car) {
    throw new NotFoundError('Vehículo');
  }

  if (!CAR_TRANSITIONS[car.status].includes(status)) {
    throw new ValidationError(
      `Transición inválida: no se puede cambiar de "${car.status}" a "${status}"`
    );
  }

  const previousStatus = car.status;
  car.status = status;
  await car.save();

  if (status === 'Cancelado' && car.capacityKey) {
    await capacity.releaseSlot(car.capacityKey);
  }

  logger.info('Estado de vehículo actualizado', { carId, from: previousStatus, to: status });
  return car;
};

/**
 * Cierra el vehículo como Completado y crea el pago pendiente. Crea el pago
 * primero; si falla el guardado del auto, lo elimina (rollback manual).
 */
const closeCar = async (carId) => {
  const car = await Car.findById(carId);
  if (!car) {
    throw new NotFoundError('Vehículo');
  }

  if (car.status !== 'En Progreso') {
    throw new ValidationError(
      `No se puede cerrar un vehículo con estado "${car.status}". Solo vehículos "En Progreso".`
    );
  }

  const payment = await Payment.create({
    userId: car.userId,
    plate: car.plate,
    method: 'Otro',
    amount: car.amount || 0,
    status: 'Pendiente',
    carId: car._id,
  });

  car.status = 'Completado';
  await car.save().catch(async (err) => {
    await Payment.findByIdAndDelete(payment._id);
    throw err;
  });

  logger.info('Vehículo cerrado como completado', {
    carId,
    plate: car.plate,
    paymentId: payment._id,
  });
  return { car, payment };
};

module.exports = { registerCar, changeStatus, closeCar };
