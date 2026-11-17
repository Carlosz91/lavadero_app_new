const Car = require('../models/carModel');
const DayCapacity = require('../models/dayCapacityModel');

const MAX_PER_DAY = parseInt(process.env.DAILY_CAPACITY, 10) || 5;
// Zona horaria del negocio: el "día" de un agendamiento se define en hora local, no UTC.
const BUSINESS_TZ = process.env.BUSINESS_TZ || 'America/Asuncion';

const DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Clave de día 'YYYY-MM-DD'. Una fecha sin hora ('2026-11-20') ya ES el día;
 * una con hora se convierte a la zona del negocio.
 */
const dayKey = (input) => {
  if (typeof input === 'string' && DATE_ONLY.test(input)) return input;
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) return null;
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: BUSINESS_TZ,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);
};

// Autos ya agendados antes de existir el contador (migración perezosa por día).
const seedCount = (key) => {
  const start = new Date(`${key}T00:00:00.000Z`);
  const end = new Date(`${key}T23:59:59.999Z`);
  return Car.countDocuments({
    scheduledDate: { $gte: start, $lte: end },
    status: { $ne: 'Cancelado' },
  });
};

const ensureCounter = async (key) => {
  if (await DayCapacity.exists({ date: key })) return;
  try {
    await DayCapacity.create({ date: key, count: await seedCount(key) });
  } catch (err) {
    if (err.code !== 11000) throw err; // otro request lo creó primero
  }
};

/**
 * Reserva un cupo de forma atómica. El filtro `count < MAX` y el $inc ocurren en
 * una sola operación, así que dos requests simultáneos no pueden pasarse del límite.
 * @returns {Promise<boolean>} true si había cupo
 */
const reserveSlot = async (key) => {
  await ensureCounter(key);
  const doc = await DayCapacity.findOneAndUpdate(
    { date: key, count: { $lt: MAX_PER_DAY } },
    { $inc: { count: 1 } },
    { new: true }
  );
  return !!doc;
};

const releaseSlot = async (key) => {
  if (!key) return;
  await DayCapacity.updateOne({ date: key, count: { $gt: 0 } }, { $inc: { count: -1 } });
};

const getBooked = async (key) => {
  await ensureCounter(key);
  const doc = await DayCapacity.findOne({ date: key });
  return doc ? doc.count : 0;
};

module.exports = { MAX_PER_DAY, dayKey, reserveSlot, releaseSlot, getBooked };
