const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const verifyToken = require('../middlewares/verifyToken');
const {
  handleValidationErrors,
  validatePaymentCreate,
  validatePaymentStatusUpdate,
} = require('../middlewares/validationMiddleware');

/**
 * @swagger
 * tags:
 *   name: Payments
 *   description: Gestión de pagos del sistema
 */

/**
 * @swagger
 * /api/payments:
 *   post:
 *     summary: Registrar un pago
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [plate, method, amount]
 *             properties:
 *               plate:
 *                 type: string
 *               method:
 *                 type: string
 *                 enum: [Efectivo, Tarjeta, Transferencia, Otro]
 *               amount:
 *                 type: number
 *               carId:
 *                 type: string
 *     responses:
 *       201:
 *         description: Pago registrado correctamente
 *       400:
 *         description: Datos inválidos
 *       401:
 *         description: No autorizado
 */
router.post(
  '/',
  verifyToken,
  validatePaymentCreate,
  handleValidationErrors,
  paymentController.createPayment
);

/**
 * @swagger
 * /api/payments:
 *   get:
 *     summary: Obtener pagos del usuario autenticado
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista de pagos del usuario autenticado
 */
router.get('/', verifyToken, paymentController.getPaymentsAuthenticated);

/**
 * @swagger
 * /api/payments/user/{userId}:
 *   get:
 *     summary: Obtener pagos por userId (admin)
 *     tags: [Payments]
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
 *         description: Pagos del usuario
 */
router.get('/user/:userId', verifyToken, paymentController.getPaymentsByUserId);

/**
 * @swagger
 * /api/payments/{id}:
 *   put:
 *     summary: Actualizar estado de un pago
 *     tags: [Payments]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
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
 *                 enum: [Pendiente, Pagado, Cancelado, Reembolsado]
 *     responses:
 *       200:
 *         description: Pago actualizado correctamente
 *       400:
 *         description: Estado inválido
 *       401:
 *         description: No autorizado
 */
router.put(
  '/:id',
  verifyToken,
  validatePaymentStatusUpdate,
  handleValidationErrors,
  paymentController.updatePaymentStatus
);

module.exports = router;
