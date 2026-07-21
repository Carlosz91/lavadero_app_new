const User = require('../models/userModel');
const logger = require('../utils/logger');

exports.getDashboard = async (req, res, next) => {
  try {
    res.json({ message: 'Dashboard administrativo' });
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
