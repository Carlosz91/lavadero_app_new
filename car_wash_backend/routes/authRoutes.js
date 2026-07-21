const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
// ✅ Importar middleware de validación
const { 
  validateRegister, 
  validateLogin, 
  handleValidationErrors 
} = require('../middlewares/validationMiddleware');
// ✅ Importar rate limiter
const { authLimiter, registerLimiter } = require('../middlewares/rateLimitMiddleware');
// ✅ Importar token verification
const verifyToken = require('../middlewares/verifyToken');

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Autenticación de usuarios
 */

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Registrar un nuevo usuario
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Usuario registrado correctamente
 *       400:
 *         description: Datos inválidos
 */
// ✅ Agregar middleware de validación y rate limiting
router.post(
  '/register',
  registerLimiter, // Rate limiting de registro
  validateRegister, // Validadores de express-validator
  handleValidationErrors, // Manejador de errores de validación
  authController.registerUser
);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Login de usuario
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login exitoso
 *       401:
 *         description: Credenciales incorrectas
 */
// ✅ Agregar rate limiting contra fuerza bruta
router.post(
  '/login',
  authLimiter, // Rate limiting de login
  validateLogin, // Validadores
  handleValidationErrors,
  authController.loginUser
);

// ✅ Endpoint para refresh token
router.post('/refresh', authController.refreshToken);

// ✅ Endpoint para cambiar contraseña
router.put(
  '/change-password',
  verifyToken, // Requiere autenticación
  authController.changePassword
);

// ✅ Endpoint para logout (solo limpiar frontend)
/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Logout de usuario
 *     tags: [Auth]
 *     responses:
 *       200:
 *         description: Logout exitoso
 */
router.post('/logout', (req, res) => {
  // El logout se maneja en el frontend eliminando el token
  res.status(200).json({ message: 'Logout exitoso' });
});

module.exports = router;
