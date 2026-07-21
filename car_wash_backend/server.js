const express = require('express');
const path = require('path');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const logger = require('./utils/logger');
const requestId = require('./utils/requestId');
const sanitizeInput = require('./middlewares/sanitize');
const { globalLimiter } = require('./middlewares/rateLimitMiddleware');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

app.use(requestId);

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(',')
    : true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
}));

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'", "http://localhost:5000", "https://lavaderoappnew-production.up.railway.app"],
      fontSrc: ["'self'"],
      objectSrc: ["'none'"],
      frameAncestors: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,
}));

// Stripe webhook necesita body raw (antes de express.json)
app.use((req, res, next) => {
  if (req.path === '/api/stripe/webhook') {
    express.raw({ type: 'application/json' })(req, res, next);
  } else {
    express.json({ limit: '10kb' })(req, res, next);
  }
});
app.use(express.urlencoded({ limit: '10kb' }));
app.use(sanitizeInput);

if (process.env.NODE_ENV !== 'test') {
  app.use(globalLimiter);
}

app.use('/admin', express.static(path.join(__dirname, 'admin-panel'), { index: 'index.html' }));
app.get('/admin', (req, res) => res.redirect('/admin/'));

app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/cars', require('./routes/carRoutes'));
app.use('/api/payments', require('./routes/paymentRoutes'));
app.use('/api/stripe', require('./routes/stripeRoutes'));
app.use('/api/admin', require('./adminRoutes'));

app.get('/health', async (req, res) => {
  const mongoState = mongoose.connection.readyState;
  const mongoStatus = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
  };

  const healthy = mongoState === 1;

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'OK' : 'DEGRADED',
    message: healthy ? 'Servidor funcionando correctamente' : 'MongoDB no disponible',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    mongodb: mongoStatus[mongoState] || 'unknown',
  });
});

app.get('/api/routes-check', (req, res) => {
  res.json({
    auth: '/api/auth',
    cars: '/api/cars',
    payments: '/api/payments',
    admin: '/api/admin',
    docs: '/api/docs',
    health: '/health',
  });
});

const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./swagger');
app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

app.use(errorHandler);

app.use((req, res) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

if (process.env.NODE_ENV !== 'test') {
  const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/car_wash';

  if (process.env.NODE_ENV === 'production' && !process.env.MONGO_URI) {
    logger.error('MONGO_URI no está configurado en producción');
    process.exit(1);
  }

  mongoose.connect(mongoUri, {
    maxPoolSize: 10,
    minPoolSize: 5,
    serverSelectionTimeoutMS: 5000,
  })
  .then(() => {
    logger.info('MongoDB conectado');
    const PORT = process.env.PORT || 5000;
    app.listen(PORT, () => {
      logger.info(`Servidor corriendo en puerto ${PORT}`);
      logger.info(`Swagger: http://localhost:${PORT}/api/docs`);
    });
  })
  .catch(err => {
    logger.error('Error conectando a MongoDB', { error: err.message });
    process.exit(1);
  });
}

module.exports = app;
