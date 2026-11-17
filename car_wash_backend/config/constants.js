// Única fuente de verdad de los catálogos del dominio. Modelos, validadores y
// controladores importan de acá: agregar un valor se hace en un solo lugar.
const { VALID_WASH_TYPES } = require('./priceCatalog');

const CAR_STATUSES = ['Pendiente', 'En Progreso', 'Completado', 'Cancelado'];

// Transiciones permitidas del estado de un lavado.
const CAR_TRANSITIONS = {
  Pendiente: ['En Progreso', 'Cancelado'],
  'En Progreso': ['Completado', 'Cancelado'],
  Completado: [],
  Cancelado: [],
};

const PAYMENT_METHODS = ['Efectivo', 'Tarjeta', 'Transferencia', 'Mercado Pago', 'Stripe', 'Otro'];
const PAYMENT_STATUSES = ['Pendiente', 'Pagado', 'Cancelado', 'Reembolsado'];

const USER_ROLES = ['user', 'admin', 'staff'];

module.exports = {
  WASH_TYPES: VALID_WASH_TYPES,
  CAR_STATUSES,
  CAR_TRANSITIONS,
  PAYMENT_METHODS,
  PAYMENT_STATUSES,
  USER_ROLES,
};
