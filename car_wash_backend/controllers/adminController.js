const User = require('../models/userModel');
const Car = require('../models/carModel');
const Payment = require('../models/paymentModel');
const logger = require('../utils/logger');

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_RANGE_DAYS = 366;
const MOVEMENTS_LIMIT = 300;

// Zona horaria local del servidor para agrupar por d�a (full ICU en Node moderno).
const LOCAL_TZ = Intl && Intl.DateTimeFormat ? Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC' : 'UTC';

const startOfToday = () => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
};

/**
 * @desc    Dashboard administrativo: estado actual + métricas del día.
 *          Los counts históricos se mantienen por compatibilidad; las tarjetas
 *          del panel usan `today` para no confundir acumulados con operativa.
 * @route   GET /api/admin/dashboard
 * @access  Private (admin)
 */
exports.getDashboard = async (req, res, next) => {
  try {
    const hoy = startOfToday();

    const [
      totalUsers,
      newUsersToday,
      totalCars,
      carsByStatus,
      carsToday,
      completedToday,
      totalPayments,
      paymentsByStatus,
      collectedToday,
      recentCars,
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ createdAt: { $gte: hoy } }),
      Car.countDocuments(),
      Car.aggregate([{ $group: { _id: '$status', count: { $sum: 1 } } }]),
      Car.countDocuments({ createdAt: { $gte: hoy } }),
      Car.countDocuments({ status: 'Completado', updatedAt: { $gte: hoy } }),
      Payment.countDocuments(),
      Payment.aggregate([{ $group: { _id: '$status', count: { $sum: 1 }, total: { $sum: '$amount' } } }]),
      Payment.aggregate([
        { $match: { status: 'Pagado', updatedAt: { $gte: hoy } } },
        { $group: { _id: null, count: { $sum: 1 }, total: { $sum: '$amount' } } },
      ]),
      Car.find().sort({ createdAt: -1 }).limit(5).select('plate brand model status amount createdAt userId').populate('userId', 'email'),
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
      // Vista operativa del día (se renueva cada medianoche local).
      today: {
        cars: carsToday,
        completed: completedToday,
        collected: collectedToday[0] || { count: 0, total: 0 },
        newUsers: newUsersToday,
      },
      recentCars,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * @desc    Reportes con rango de fechas: resumen agregado, movimiento por día
 *          y detalle de cobros (movimientos) del rango.
 * @route   GET /api/admin/reports?from=YYYY-MM-DD&to=YYYY-MM-DD
 * @access  Private (admin)
 */
exports.getReports = async (req, res, next) => {
  try {
    const { from, to } = req.query;
    let start;
    let end;

    if (from || to) {
      if (!from || !to) {
        return res.status(400).json({ error: 'Deben enviarse from y to juntos' });
      }
      if (!DATE_ONLY.test(from) || !DATE_ONLY.test(to)) {
        return res.status(400).json({ error: 'Las fechas deben tener formato YYYY-MM-DD' });
      }
      start = new Date(`${from}T00:00:00`);
      end = new Date(`${to}T23:59:59.999`);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
        return res.status(400).json({ error: 'Fechas inválidas' });
      }
      if (end < start) {
        return res.status(400).json({ error: 'La fecha final debe ser posterior a la inicial' });
      }
      if (end - start > MAX_RANGE_DAYS * DAY_MS + DAY_MS) {
        return res.status(400).json({ error: `El rango máximo es de ${MAX_RANGE_DAYS} días` });
      }
    } else {
      // Sin filtros: mes en curso por defecto.
      const now = new Date();
      start = new Date(now.getFullYear(), now.getMonth(), 1);
      end = now;
    }

    const [
      totalCarsRange,
      carsByStatusRange,
      completedRange,
      totalUsersRange,
      paymentsByStatusRange,
      movements,
      dailyCars,
      dailyPaid,
    ] = await Promise.all([
      Car.countDocuments({ createdAt: { $gte: start, $lte: end } }),
      Car.aggregate([
        { $match: { createdAt: { $gte: start, $lte: end } } },
        { $group: { _id: '$status', count: { $sum: 1 } } },
      ]),
      Car.countDocuments({ status: 'Completado', updatedAt: { $gte: start, $lte: end } }),
      User.countDocuments({ createdAt: { $gte: start, $lte: end } }),
      Payment.aggregate([
        { $match: { date: { $gte: start, $lte: end } } },
        { $group: { _id: '$status', count: { $sum: 1 }, total: { $sum: '$amount' } } },
      ]),
      Payment.find({ date: { $gte: start, $lte: end } })
        .sort({ date: -1 })
        .limit(MOVEMENTS_LIMIT)
        .select('plate amount status method date userId')
        .populate('userId', 'email'),
      // Movimiento diario: autos registrados y cobrado por día (hora local).
      Car.aggregate([
        { $match: { createdAt: { $gte: start, $lte: end } } },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt', timezone: LOCAL_TZ } },
            cars: { $sum: 1 },
          },
        },
      ]),
      Payment.aggregate([
        { $match: { status: 'Pagado', date: { $gte: start, $lte: end } } },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$date', timezone: LOCAL_TZ } },
            collected: { $sum: '$amount' },
            payments: { $sum: 1 },
          },
        },
      ]),
    ]);

    const carsMap = { Pendiente: 0, 'En Progreso': 0, Completado: 0, Cancelado: 0 };
    carsByStatusRange.forEach(s => { carsMap[s._id] = s.count; });

    const payMap = {
      Pendiente: { count: 0, total: 0 },
      Pagado: { count: 0, total: 0 },
      Cancelado: { count: 0, total: 0 },
      Reembolsado: { count: 0, total: 0 },
    };
    paymentsByStatusRange.forEach(s => {
      if (payMap[s._id]) payMap[s._id] = { count: s.count, total: s.total };
    });

    // Merge de las dos series diarias, ordenadas por fecha.
    const byDay = {};
    dailyCars.forEach(d => { byDay[d._id] = { day: d._id, cars: d.cars, collected: 0, payments: 0 }; });
    dailyPaid.forEach(d => {
      if (!byDay[d._id]) byDay[d._id] = { day: d._id, cars: 0, collected: 0, payments: 0 };
      byDay[d._id].collected = d.collected;
      byDay[d._id].payments = d.payments;
    });
    const daily = Object.values(byDay).sort((a, b) => a.day.localeCompare(b.day));

    res.json({
      range: { from: start, to: end },
      summary: {
        cars: totalCarsRange,
        carsByStatus: carsMap,
        completados: completedRange,
        newUsers: totalUsersRange,
        payments: payMap,
      },
      daily,
      movements,
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
