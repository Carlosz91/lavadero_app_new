const Car = require('../models/carModel');
const User = require('../models/userModel');
const { NotFoundError, ValidationError, ForbiddenError } = require('../utils/AppError');
const capacity = require('../services/capacityService');
const carService = require('../services/carService');

const summary = (car) => ({
  _id: car._id,
  plate: car.plate,
  status: car.status,
  updatedAt: car.updatedAt,
});

/**
 * @desc    Registra un vehículo para lavado. Verifica pagos pendientes, existencia del usuario y capacidad de agendamiento.
 * @route   POST /api/cars/registercar
 * @access  Private (user)
 */
exports.registerCar = async (req, res, next) => {
  try {
    const car = await carService.registerCar(req.user.id, req.body);
    res.status(201).json({ message: 'Vehículo registrado exitosamente', car });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Obtiene vehículos del usuario con paginación
 * @route   GET /api/cars/status/:userId
 * @access  Private (owner or admin)
 */
exports.getUserCarsStatus = async (req, res, next) => {
  try {
    const { userId } = req.params;

    if (req.user.id !== userId && req.user.role !== 'admin') {
      throw new ForbiddenError('No tienes permiso para ver estos vehículos');
    }

    const user = await User.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario');
    }

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [cars, total] = await Promise.all([
      Car.find({ userId })
        .select(
          'plate model brand color washType amount status scheduledDate scheduledTime createdAt updatedAt'
        )
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit),
      Car.countDocuments({ userId }),
    ]);

    res.status(200).json({
      data: cars,
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
 * @desc    Actualiza estado del lavado (admin/staff). Valida transiciones permitidas.
 * @route   PUT /api/cars/update-status/:carId
 * @access  Private (admin, staff)
 */
exports.updateCarStatus = async (req, res, next) => {
  try {
    const { status } = req.body;
    const car = await carService.changeStatus(req.params.carId, status);
    res.status(200).json({
      message: `Estado actualizado a "${status}"`,
      car: summary(car),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Cierra vehículo como Completado y crea pago pendiente. Crea pago primero, si falla el guardado del auto elimina el pago (rollback manual).
 * @route   PUT /api/cars/close-car/:carId
 * @access  Private (admin, staff)
 */
exports.closeCarStatus = async (req, res, next) => {
  try {
    const { car } = await carService.closeCar(req.params.carId);
    res.status(200).json({
      message: 'Vehículo marcado como Completado',
      car: summary(car),
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Obtiene estadísticas de lavado por usuario (agrupado por estado)
 * @route   GET /api/cars/stats/:userId
 * @access  Private (owner or admin)
 */
exports.getCarsStats = async (req, res, next) => {
  try {
    const { userId } = req.params;

    if (req.user.id !== userId && req.user.role !== 'admin') {
      throw new ForbiddenError('No tienes permiso para ver estas estadísticas');
    }

    const user = await User.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario');
    }

    const stats = await Car.aggregate([
      { $match: { userId: new (require('mongoose').Types.ObjectId)(userId) } },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          totalAmount: { $sum: '$amount' },
        },
      },
    ]);

    const formattedStats = {
      Pendiente: { count: 0, totalAmount: 0 },
      'En Progreso': { count: 0, totalAmount: 0 },
      Completado: { count: 0, totalAmount: 0 },
      Cancelado: { count: 0, totalAmount: 0 },
    };

    stats.forEach((stat) => {
      formattedStats[stat._id] = {
        count: stat.count,
        totalAmount: stat.totalAmount,
      };
    });

    res.status(200).json({
      message: 'Estadísticas obtenidas exitosamente',
      stats: formattedStats,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Verifica disponibilidad de agendamiento para una fecha (máx 5 autos/día)
 * @route   GET /api/cars/availability?date=YYYY-MM-DD
 * @access  Private
 */
exports.checkAvailability = async (req, res, next) => {
  try {
    const { date } = req.query;
    if (!date) {
      throw new ValidationError('Fecha es requerida (YYYY-MM-DD)');
    }

    const key = capacity.dayKey(date);
    if (!key) {
      throw new ValidationError('Fecha inválida (YYYY-MM-DD)');
    }
    const count = await capacity.getBooked(key);

    res.status(200).json({
      date,
      booked: count,
      available: Math.max(0, capacity.MAX_PER_DAY - count),
      maxPerDay: capacity.MAX_PER_DAY,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Devuelve el catálogo de precios oficial desde el servidor
 * @route   GET /api/cars/prices
 * @access  Public
 */
exports.getPrices = async (_req, res, next) => {
  try {
    const { WASH_TYPE_PRICES } = require('../config/priceCatalog');
    res.status(200).json({
      prices: WASH_TYPE_PRICES,
      currency: 'PYG',
      updatedAt: new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
};
