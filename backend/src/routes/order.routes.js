const router = require('express').Router();
const { body, param } = require('express-validator');
const { authenticate } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const ctrl = require('../controllers/order.controller');

router.use(authenticate);

const checkoutRules = [
  body('shipping_address.name').notEmpty().withMessage('Shipping name required'),
  body('shipping_address.address').notEmpty().withMessage('Shipping address required'),
  body('shipping_address.city').notEmpty().withMessage('City required'),
  body('payment.card_number').notEmpty().withMessage('Card number required'),
  body('payment.expiry').notEmpty().withMessage('Expiry required'),
  body('payment.cvv').isLength({ min: 3, max: 4 }).withMessage('CVV required'),
];

router.post('/checkout', checkoutRules, validate, ctrl.checkout);
router.get('/', ctrl.listOrders);
router.get('/:id', param('id').isUUID(), validate, ctrl.getOrder);

module.exports = router;
