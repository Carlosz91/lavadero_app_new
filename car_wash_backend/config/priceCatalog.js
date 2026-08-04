const WASH_TYPE_PRICES = {
  'B\u00e1sico': 50000,
  'Premium': 80000,
  'Premium Plus': 100000,
  'Completo': 120000,
  'Detailing': 200000,
  'Full Package': 300000,
};

const VALID_WASH_TYPES = Object.keys(WASH_TYPE_PRICES);

const getPriceForWashType = (washType) => WASH_TYPE_PRICES[washType] || null;

module.exports = { WASH_TYPE_PRICES, VALID_WASH_TYPES, getPriceForWashType };
