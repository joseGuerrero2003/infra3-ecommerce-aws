const { verifyAccessToken } = require('../utils/jwt.utils');
const { unauthorized, forbidden } = require('../utils/responseHelper');
const { User } = require('../models');

const authenticate = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return unauthorized(res, 'No token provided');
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = verifyAccessToken(token);
    const user = await User.findByPk(decoded.id, {
      attributes: ['id', 'username', 'email', 'role'],
    });
    if (!user) return unauthorized(res, 'User not found');
    req.user = user;
    next();
  } catch (err) {
    return unauthorized(res, 'Invalid or expired token');
  }
};

const requireAdmin = (req, res, next) => {
  if (!req.user || req.user.role !== 'admin') {
    return forbidden(res, 'Admin access required');
  }
  next();
};

module.exports = { authenticate, requireAdmin };
