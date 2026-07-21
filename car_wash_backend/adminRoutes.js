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
 *       401:
 *         description: No autorizado
 *       403:
 *         description: Se requiere rol de admin
 */
router.get('/dashboard', verifyToken, requireRole('admin'), adminController.getDashboard);

module.exports = router;
