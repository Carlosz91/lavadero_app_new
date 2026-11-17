// Validación centralizada de variables de entorno. Se ejecuta al arrancar para
// fallar rápido y con un mensaje claro, en vez de romper en mitad de una petición.
const PLACEHOLDER = /change[-_ ]?(this|me)|your[-_ ]|example/i;

/**
 * @param {NodeJS.ProcessEnv} env
 * @returns {{ errors: string[], warnings: string[] }}
 */
const validateEnv = (env = process.env) => {
  const errors = [];
  const warnings = [];
  const prod = env.NODE_ENV === 'production';

  if (!env.JWT_SECRET) {
    errors.push('JWT_SECRET es obligatorio');
  } else if (prod && (env.JWT_SECRET.length < 32 || PLACEHOLDER.test(env.JWT_SECRET))) {
    errors.push('JWT_SECRET debe tener al menos 32 caracteres y no ser un valor de ejemplo');
  } else if (env.JWT_SECRET.length < 32) {
    warnings.push('JWT_SECRET es corto (<32 caracteres): usa un secreto largo y aleatorio');
  }

  if (prod) {
    if (!env.MONGO_URI) errors.push('MONGO_URI es obligatorio en producción');

    if (!env.JWT_REFRESH_SECRET) {
      errors.push('JWT_REFRESH_SECRET es obligatorio en producción');
    } else if (env.JWT_REFRESH_SECRET === env.JWT_SECRET) {
      errors.push('JWT_REFRESH_SECRET debe ser distinto de JWT_SECRET');
    } else if (env.JWT_REFRESH_SECRET.length < 32 || PLACEHOLDER.test(env.JWT_REFRESH_SECRET)) {
      errors.push(
        'JWT_REFRESH_SECRET debe tener al menos 32 caracteres y no ser un valor de ejemplo'
      );
    }

    if (!env.ALLOWED_ORIGINS) {
      warnings.push('ALLOWED_ORIGINS no definido: solo se permitirán orígenes de desarrollo');
    }
    if (!env.GOOGLE_CLIENT_ID) {
      warnings.push('GOOGLE_CLIENT_ID no definido: el login con Google responderá error');
    }
    if (Boolean(env.STRIPE_SECRET_KEY) !== Boolean(env.STRIPE_WEBHOOK_SECRET)) {
      errors.push('STRIPE_SECRET_KEY y STRIPE_WEBHOOK_SECRET deben definirse juntos');
    }
    if (!env.STRIPE_SECRET_KEY) {
      warnings.push('Stripe no configurado: los pagos en línea no funcionarán');
    }
    if (env.RATE_LIMIT_MAX) {
      warnings.push('RATE_LIMIT_MAX está definido: es solo para desarrollo, quítalo en producción');
    }
  }

  return { errors, warnings };
};

/** Lanza si hay errores (salvo en tests); registra las advertencias. */
const assertEnv = (env = process.env, log = console) => {
  if (env.NODE_ENV === 'test') return;
  const { errors, warnings } = validateEnv(env);
  warnings.forEach((w) => log.warn(`[env] ${w}`));
  if (errors.length) {
    throw new Error(`Configuración inválida:\n - ${errors.join('\n - ')}`);
  }
};

module.exports = { validateEnv, assertEnv };
