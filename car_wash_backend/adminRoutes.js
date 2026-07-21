const express = require('express');
const router = express.Router();
const verifyToken = require('./middlewares/verifyToken');
const { requireRole } = require('./middlewares/verifyToken');

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
router.get('/dashboard', verifyToken, requireRole('admin'), (req, res) => {
  res.json({ message: 'Dashboard administrativo' });
});

module.exports = router;
