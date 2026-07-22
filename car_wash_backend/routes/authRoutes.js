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

/**
 * @swagger
 * /api/auth/google:
 *   post:
 *     summary: Iniciar sesión con Google
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [idToken]
 *             properties:
 *               idToken:
 *                 type: string
 *                 description: Token de ID de Google
 *     responses:
 *       200:
 *         description: Login exitoso, devuelve token JWT
 *       400:
 *         description: Token inválido
 */
router.post('/google', authController.googleLogin);

/**
 * @swagger
 * /api/auth/refresh:
 *   post:
 *     summary: Renovar token JWT
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token]
 *             properties:
 *               token:
 *                 type: string
 *                 description: Token JWT actual o refresh token
 *     responses:
 *       200:
 *         description: Token renovado exitosamente
 *       401:
 *         description: Token inválido o expirado
 */
router.post('/refresh', authController.refreshToken);

/**
 * @swagger
 * /api/auth/change-password:
 *   put:
 *     summary: Cambiar contraseña
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword:
 *                 type: string
 *                 format: password
 *               newPassword:
 *                 type: string
 *                 format: password
 *     responses:
 *       200:
 *         description: Contraseña cambiada exitosamente
 *       400:
 *         description: Contraseña actual incorrecta o nueva inválida
 *       401:
 *         description: No autorizado
 */
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
