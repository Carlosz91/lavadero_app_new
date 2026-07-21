const express = require('express');
const router = express.Router();
const stripeController = require('../controllers/stripeController');
const verifyToken = require('../middlewares/verifyToken');

router.post('/create-checkout-session', verifyToken, stripeController.createCheckoutSession);
router.get('/success', stripeController.success);
router.get('/cancel', stripeController.cancel);
router.post('/webhook', stripeController.webhook);

module.exports = router;
