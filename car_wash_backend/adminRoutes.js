const express = require('express');
const router = express.Router();
const verifyToken = require('./middlewares/verifyToken');
const { requireRole } = require('./middlewares/verifyToken');
const adminController = require('./controllers/adminController');

/**
 * @swagger
 * /api/admin/dashboard:
 *   get:
 *     summary: Obtener dashboard administrativo
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dashboard obtenido exitosamente
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 users:
 *                   type: integer
 *                 cars:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     Pendiente:
 *                       type: integer
 *                     'En Progreso':
 *                       type: integer
 *                     Completado:
 *                       type: integer
 *                     Cancelado:
 *                       type: integer
 *                 payments:
 *                   type: object
 *                   properties:
 *                     total:
 *                       type: integer
 *                     pending:
 *                       type: object
 *                       properties:
 *                         count:
 *                           type: integer
 *                         total:
 *                           type: number
 *                     paid:
 *                       type: object
 *                       properties:
 *                         count:
 *                           type: integer
 *                         total:
 *                           type: number
 *                 recentCars:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Car'
 *       401:
 *         description: No autorizado
 *       403:
 *         description: Se requiere rol de admin
 */

/**
 * @swagger
 * /api/admin/users/search:
 *   get:
 *     summary: Buscar usuario por email
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: email
 *         schema:
 *           type: string
 *         required: true
 *         description: Email del usuario a buscar
 *     responses:
 *       200:
 *         description: Usuario encontrado
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/User'
 *       401:
 *         description: No autorizado
 *       403:
 *         description: Se requiere rol de admin
 *       404:
 *         description: Usuario no encontrado
 */
router.get('/dashboard', verifyToken, requireRole('admin'), adminController.getDashboard);
router.get('/users/search', verifyToken, requireRole('admin'), adminController.searchUsers);

module.exports = router;
