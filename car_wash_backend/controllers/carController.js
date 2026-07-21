const Car = require('../models/carModel');
const User = require('../models/userModel');
const logger = require('../utils/logger');
const { NotFoundError, ValidationError, ForbiddenError } = require('../utils/AppError');

const VALID_WASH_TYPES = ['Básico', 'Premium', 'Completo', 'Detailing'];
const VALID_STATUSES = ['Pendiente', 'En Progreso', 'Completado', 'Cancelado'];
const VALID_TRANSITIONS = {
  'Pendiente': ['En Progreso', 'Cancelado'],
  'En Progreso': ['Completado', 'Cancelado'],
  'Completado': [],
  'Cancelado': [],
};

exports.registerCar = async (req, res, next) => {
  try {
    const { plate, model, brand, washType, amount } = req.body;
    const userId = req.user.id;

    if (!VALID_WASH_TYPES.includes(washType)) {
      throw new ValidationError(`Tipo de lavado inválido. Válidos: ${VALID_WASH_TYPES.join(', ')}`);
    }

    const user = await User.findById(userId);
    if (!user) {
      throw new NotFoundError('Usuario');
    }

    const newCar = new Car({
      plate: plate.trim().toUpperCase(),
      model: model.trim(),
      brand: brand.trim(),
      washType,
      amount,
      userId,
      status: 'Pendiente',
    });

    await newCar.save();

    logger.info('Vehículo registrado', { carId: newCar._id, userId, plate });

    res.status(201).json({
      message: 'Vehículo registrado exitosamente',
      car: newCar,
    });
  } catch (err) {
    next(err);
  }
};

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
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const [cars, total] = await Promise.all([
      Car.find({ userId })
        .select('plate model brand washType amount status createdAt updatedAt')
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

exports.updateCarStatus = async (req, res, next) => {
  try {
    const { carId } = req.params;
    const { status } = req.body;

    if (!status || !VALID_STATUSES.includes(status)) {
      throw new ValidationError(`Estado inválido. Válidos: ${VALID_STATUSES.join(', ')}`);
    }

    const car = await Car.findById(carId);
    if (!car) {
      throw new NotFoundError('Vehículo');
    }

    if (!VALID_TRANSITIONS[car.status].includes(status)) {
      throw new ValidationError(
        `Transición inválida: no se puede cambiar de "${car.status}" a "${status}"`
      );
    }

    car.status = status;
    await car.save();

    logger.info('Estado de vehículo actualizado', { carId, from: car.status, to: status });

    res.status(200).json({
      message: `Estado actualizado a "${status}"`,
      car: {
        _id: car._id,
        plate: car.plate,
        status: car.status,
        updatedAt: car.updatedAt,
      },
    });
  } catch (err) {
    next(err);
  }
};

exports.closeCarStatus = async (req, res, next) => {
  try {
    const { carId } = req.params;

    const car = await Car.findById(carId);
    if (!car) {
      throw new NotFoundError('Vehículo');
    }

    if (car.status !== 'En Progreso') {
      throw new ValidationError(
        `No se puede cerrar un vehículo con estado "${car.status}". Solo vehículos "En Progreso".`
      );
    }

    car.status = 'Completado';
    await car.save();

    logger.info('Vehículo cerrado como completado', { carId, plate: car.plate });

    res.status(200).json({
      message: 'Vehículo marcado como Completado',
      car: {
        _id: car._id,
        plate: car.plate,
        status: car.status,
        updatedAt: car.updatedAt,
      },
    });
  } catch (err) {
    next(err);
  }
};

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

    stats.forEach(stat => {
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
