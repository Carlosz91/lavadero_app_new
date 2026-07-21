const express = require('express');
const router = express.Router();
const carController = require('../controllers/carController');
const verifyToken = require('../middlewares/verifyToken');
const {
  handleValidationErrors,
  validateCarRegister,
  validateCarStatusUpdate,
  validateMongoId,
} = require('../middlewares/validationMiddleware');

/**
 * @swagger
 * tags:
 *   name: Cars
 *   description: Gestión del proceso de lavado de vehículos
 */

/**
 * @swagger
 * /api/cars/registercar:
 *   post:
 *     summary: Registrar un vehículo para lavado
 *     tags: [Cars]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [plate, brand, model, washType, amount]
 *             properties:
 *               plate:
 *                 type: string
 *               brand:
 *                 type: string
 *               model:
 *                 type: string
 *               washType:
 *                 type: string
 *                 enum: [Básico, Premium, Completo, Detailing]
 *               amount:
 *                 type: number
 *     responses:
 *       201:
 *         description: Vehículo registrado exitosamente
 *       400:
 *         description: Datos inválidos
 *       401:
 *         description: No autorizado
 */
router.post(
  '/registercar',
  verifyToken,
  validateCarRegister,
  handleValidationErrors,
  carController.registerCar
);

/**
 * @swagger
 * /api/cars/status/{userId}:
 *   get:
 *     summary: Obtener estado de los vehículos del usuario
 *     tags: [Cars]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Lista de vehículos y su estado
 *       401:
 *         description: No autorizado
 *       403:
 *         description: Acceso denegado
 */
router.get(
  '/status/:userId',
  verifyToken,
  validateMongoId('userId'),
  handleValidationErrors,
  carController.getUserCarsStatus
);

/**
 * @swagger
 * /api/cars/update-status/{carId}:
 *   put:
 *     summary: Actualizar el estado del lavado de un vehículo
 *     tags: [Cars]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: carId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [Pendiente, En Progreso, Completado, Cancelado]
 *     responses:
 *       200:
 *         description: Estado actualizado correctamente
 *       400:
 *         description: Transición inválida
 *       401:
 *         description: No autorizado
 */
router.put(
  '/update-status/:carId',
  verifyToken,
  verifyToken.requireRole('admin', 'staff'),
  validateCarStatusUpdate,
  handleValidationErrors,
  carController.updateCarStatus
);

/**
 * @swagger
 * /api/cars/close-car/{carId}:
 *   put:
 *     summary: Cerrar el proceso de lavado de un vehículo
 *     tags: [Cars]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: carId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Vehículo cerrado y marcado como completado
 *       400:
 *         description: El vehículo no está en progreso
 *       401:
 *         description: No autorizado
 */
router.put(
  '/close-car/:carId',
  verifyToken,
  verifyToken.requireRole('admin', 'staff'),
  validateMongoId('carId'),
  handleValidationErrors,
  carController.closeCarStatus
);

/**
 * @swagger
 * /api/cars/stats/{userId}:
 *   get:
 *     summary: Obtener estadísticas de lavado por usuario
 *     tags: [Cars]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: userId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Estadísticas de vehículos lavados
 *       401:
 *         description: No autorizado
 *       403:
 *         description: Acceso denegado
 */
router.get(
  '/stats/:userId',
  verifyToken,
  validateMongoId('userId'),
  handleValidationErrors,
  carController.getCarsStats
);

module.exports = router;
