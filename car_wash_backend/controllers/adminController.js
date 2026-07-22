const User = require('../models/userModel');
const Car = require('../models/carModel');
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');

exports.getDashboard = async (req, res, next) => {
  try {
    const [
      totalUsers,
      totalCars,
      carsByStatus,
      totalPayments,
      paymentsByStatus,
      recentCars,
    ] = await Promise.all([
      User.countDocuments(),
      Car.countDocuments(),
      Car.aggregate([{ $group: { _id: '$status', count: { $sum: 1 } } }]),
      Payment.countDocuments(),
      Payment.aggregate([{ $group: { _id: '$status', count: { $sum: 1 }, total: { $sum: '$amount' } } }]),
      Car.find().sort({ createdAt: -1 }).limit(5).select('plate brand model status amount createdAt'),
    ]);

    const statusMap = { Pendiente: 0, 'En Progreso': 0, Completado: 0, Cancelado: 0 };
    carsByStatus.forEach(s => { statusMap[s._id] = s.count; });

    const paymentMap = { Pendiente: { count: 0, total: 0 }, Pagado: { count: 0, total: 0 } };
    paymentsByStatus.forEach(s => {
      if (paymentMap[s._id]) paymentMap[s._id] = { count: s.count, total: s.total };
    });

    res.json({
      users: totalUsers,
      cars: { total: totalCars, ...statusMap },
      payments: {
        total: totalPayments,
        pending: paymentMap.Pendiente,
        paid: paymentMap.Pagado,
      },
      recentCars,
    });
  } catch (err) {
    next(err);
  }
};

exports.searchUsers = async (req, res, next) => {
  try {
    const { email } = req.query;
    if (!email) {
      return res.status(400).json({ error: 'Email es requerido' });
    }
    const user = await User.findOne({ email: email.toLowerCase() }).select('_id email name role');
    if (!user) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    res.json(user);
  } catch (err) {
    next(err);
  }
};
