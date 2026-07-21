const logger = require('../utils/logger');

exports.getDashboard = async (req, res, next) => {
  try {
    res.json({ message: 'Dashboard administrativo' });
  } catch (err) {
    next(err);
  }
};
