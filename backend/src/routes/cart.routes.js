const router = require('express').Router();
const { body, param } = require('express-validator');
const { authenticate } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const ctrl = require('../controllers/cart.controller');

router.use(authenticate);

router.get('/', ctrl.getCart);
router.post('/items', body('product_id').isUUID(), body('quantity').isInt({ min: 1 }), validate, ctrl.addItem);
router.put('/items/:id', param('id').isUUID(), body('quantity').isInt({ min: 1 }), validate, ctrl.updateItem);
router.delete('/items/:id', param('id').isUUID(), validate, ctrl.removeItem);
router.delete('/', ctrl.clearCart);

module.exports = router;
