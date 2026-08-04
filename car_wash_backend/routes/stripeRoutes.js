const express = require('express');
const router = express.Router();
const stripeController = require('../controllers/stripeController');
const verifyToken = require('../middlewares/verifyToken');
const idempotencyMiddleware = require('../middlewares/idempotencyMiddleware');

/**
 * @swagger
 * /api/stripe/create-checkout-session:
 *   post:
 *     summary: Crear sesión de pago Stripe
 *     description: El monto siempre proviene del pago existente (creado por el sistema o admin), nunca del cliente
 *     tags: [Stripe]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - $ref: '#/components/parameters/idempotencyKey'
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [paymentId]
 *             properties:
 *               paymentId:
 *                 type: string
 *                 example: 60d5f484f1a2c8b1f8e4e1a1
 *               description:
 *                 type: string
 *                 example: Lavado de vehículo ABC-1234
 *     responses:
 *       200:
 *         description: URL de checkout generada
 *       400:
 *         description: Datos inválidos (paymentId requerido, pago ya procesado)
 *       401:
 *         description: No autorizado
 *       403:
 *         description: No tienes permiso para pagar este pago
 *       409:
 *         description: Solicitud duplicada (misma Idempotency-Key)
 */

/**
 * @swagger
 * /api/stripe/success:
 *   get:
 *     summary: Página de éxito después del pago
 *     tags: [Stripe]
 *     responses:
 *       200:
 *         description: HTML de éxito
 */

/**
 * @swagger
 * /api/stripe/cancel:
 *   get:
 *     summary: Página de cancelación de pago
 *     tags: [Stripe]
 *     responses:
 *       200:
 *         description: HTML de cancelación
 */

/**
 * @swagger
 * /api/stripe/webhook:
 *   post:
 *     summary: Webhook de Stripe (sin autenticación)
 *     tags: [Stripe]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *     responses:
 *       200:
 *         description: Webhook procesado
 *       400:
 *         description: Firma inválida
 */

router.post('/create-checkout-session', verifyToken, idempotencyMiddleware, stripeController.createCheckoutSession);
router.get('/success', stripeController.success);
router.get('/cancel', stripeController.cancel);
router.post('/webhook', stripeController.webhook);

module.exports = router;
