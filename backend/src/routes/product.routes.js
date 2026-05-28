const router = require('express').Router();
const { body, query, param } = require('express-validator');
const { authenticate, requireAdmin } = require('../middleware/auth.middleware');
const { validate } = require('../middleware/validate.middleware');
const ctrl = require('../controllers/product.controller');

const productRules = [
  body('name').trim().notEmpty().isLength({ max: 255 }),
  body('price').isFloat({ min: 0 }),
  body('stock').isInt({ min: 0 }),
  body('description').optional().trim(),
  body('category').optional().trim().isLength({ max: 100 }),
  body('image_url').optional().isURL(),
];

router.get('/', ctrl.list);
router.get('/:id', param('id').isUUID(), validate, ctrl.getOne);
router.post('/', authenticate, requireAdmin, productRules, validate, ctrl.create);
router.put('/:id', authenticate, requireAdmin, param('id').isUUID(), productRules, validate, ctrl.update);
router.delete('/:id', authenticate, requireAdmin, param('id').isUUID(), validate, ctrl.remove);

module.exports = router;
