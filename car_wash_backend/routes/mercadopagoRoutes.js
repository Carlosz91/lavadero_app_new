const express = require('express');
const router = express.Router();
const mpController = require('../controllers/mercadopagoController');
const verifyToken = require('../middlewares/verifyToken');

router.post('/create-preference', verifyToken, mpController.createPreference);
router.get('/success', mpController.success);
router.get('/failure', mpController.failure);
router.get('/pending', mpController.pending);
router.post('/webhook', mpController.webhook);

module.exports = router;
