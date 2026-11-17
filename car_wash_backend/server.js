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
const { assertEnv } = require('./config/env');
const monitoring = require('./utils/monitoring');

// Falla rápido si la configuración es inválida (antes de cargar rutas/controladores).
assertEnv(process.env, logger);
monitoring.init();

const app = express();
app.set('trust proxy', 1);

app.use(requestId);

// CORS: por defecto solo orígenes de desarrollo. En producción definir
// ALLOWED_ORIGINS (lista separada por comas). La app móvil nativa no usa CORS
// (no envía Origin); el panel admin y el frontend web se sirven desde el mismo
// origen, y la autenticación va por header Authorization (no se necesita credentials).
const DEFAULT_ALLOWED_ORIGINS = [
  'http://localhost:5000',
  'http://localhost:3000',
  'http://localhost:5099',
];
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',')
      .map((o) => o.trim())
      .filter(Boolean)
  : DEFAULT_ALLOWED_ORIGINS;

app.use(
  cors({
    origin: allowedOrigins,
    credentials: false,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  })
);

app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        // Sin 'unsafe-inline': un <script> o handler inyectado (XSS) no se ejecuta.
        scriptSrc: ["'self'"],
        scriptSrcAttr: ["'none'"],
        styleSrc: ["'self'", "'unsafe-inline'", 'https://cdnjs.cloudflare.com'],
        imgSrc: ["'self'", 'data:'],
        connectSrc: [
          "'self'",
          'http://localhost:5000',
          'https://lavaderoappnew-production.up.railway.app',
          'https://lavaderoappnew-development.up.railway.app',
        ],
        fontSrc: ["'self'", 'https://cdnjs.cloudflare.com'],
        objectSrc: ["'none'"],
        frameAncestors: ["'none'"],
      },
    },
    crossOriginEmbedderPolicy: false,
  })
);

app.use((req, res, next) => {
  if (req.path === '/api/stripe/webhook') {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
    });
    req.on('end', () => {
      req.rawBody = data;
      next();
    });
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

  mongoose
    .connect(mongoUri, {
      maxPoolSize: 10,
      minPoolSize: 5,
      serverSelectionTimeoutMS: 5000,
    })
    .then(() => {
      logger.info('MongoDB conectado');
      // Reemplaza el viejo índice único global de Idempotency.key por {userId, key}.
      return require('./models/idempotencyModel')
        .syncIndexes()
        .catch((err) =>
          logger.warn('No se pudieron sincronizar índices de Idempotency', { error: err.message })
        );
    })
    .then(() => {
      const PORT = process.env.PORT || 5000;
      const server = app.listen(PORT, () => {
        logger.info(`Servidor corriendo en puerto ${PORT}`);
        logger.info(`Swagger: http://localhost:${PORT}/api/docs`);
      });

      // Conciliación periódica de pagos Stripe cuyo webhook no llegó.
      const stopReconciler = require('./services/paymentReconciler').startReconciler(
        require('./controllers/stripeController').getStripe
      );

      // Timeouts razonables contra conexiones lentas (slowloris).
      server.requestTimeout = 30000;
      server.headersTimeout = 35000;
      server.keepAliveTimeout = 65000; // > timeout típico de los balanceadores (60s)

      // Cierre ordenado: deja de aceptar conexiones, termina las en curso y cierra Mongo.
      let shuttingDown = false;
      const shutdown = (signal) => {
        if (shuttingDown) return;
        shuttingDown = true;
        logger.info(`${signal} recibido: cerrando servidor`);
        const force = setTimeout(() => {
          logger.error('Cierre forzado por timeout');
          process.exit(1);
        }, 10000);
        force.unref();
        stopReconciler();
        server.close(async () => {
          try {
            await monitoring.flush();
            await mongoose.connection.close();
          } finally {
            process.exit(0);
          }
        });
      };
      process.on('SIGTERM', () => shutdown('SIGTERM'));
      process.on('SIGINT', () => shutdown('SIGINT'));
    })
    .catch((err) => {
      logger.error('Error conectando a MongoDB', { error: err.message });
      process.exit(1);
    });
}

if (process.env.NODE_ENV !== 'test') {
  process.on('unhandledRejection', (reason) => {
    logger.error('unhandledRejection', {
      reason: reason && reason.message ? reason.message : String(reason),
    });
  });
  process.on('uncaughtException', (err) => {
    logger.error('uncaughtException', { error: err.message, stack: err.stack });
    monitoring.captureException(err, { type: 'uncaughtException' });
    monitoring.flush().finally(() => process.exit(1)); // estado indefinido: el orquestador reinicia el contenedor
  });
}

module.exports = app;
