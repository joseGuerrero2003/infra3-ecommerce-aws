const router = require('express').Router();
const { body } = require('express-validator');
const { authLimiter } = require('../middleware/rateLimiter.middleware');
const { validate } = require('../middleware/validate.middleware');
const { authenticate } = require('../middleware/auth.middleware');
const ctrl = require('../controllers/auth.controller');

const registerRules = [
  body('username').trim().isLength({ min: 3, max: 50 }).withMessage('Username must be 3-50 chars'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
  body('password').isLength({ min: 8 }).withMessage('Password min 8 chars')
    .matches(/(?=.*[A-Z])(?=.*[0-9])/).withMessage('Password needs uppercase and number'),
];

const loginRules = [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
];

router.post('/register', authLimiter, registerRules, validate, ctrl.register);
router.post('/login', authLimiter, loginRules, validate, ctrl.login);
router.post('/logout', authenticate, ctrl.logout);
router.get('/profile', authenticate, ctrl.getProfile);

module.exports = router;
