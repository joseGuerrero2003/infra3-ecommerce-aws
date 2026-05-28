const bcrypt = require('bcryptjs');
const { User, Cart } = require('../models');
const { generateAccessToken, generateRefreshToken } = require('../utils/jwt.utils');
const { success, created, unauthorized, error } = require('../utils/responseHelper');
const logger = require('../utils/logger');

const register = async (req, res, next) => {
  try {
    const { username, email, password } = req.body;

    const existing = await User.findOne({ where: { email } });
    if (existing) return error(res, 'Email already registered', 409);

    const existingUsername = await User.findOne({ where: { username } });
    if (existingUsername) return error(res, 'Username already taken', 409);

    const password_hash = await bcrypt.hash(password, 10);
    const user = await User.create({ username, email, password_hash });

    await Cart.create({ user_id: user.id });

    const accessToken = generateAccessToken({ id: user.id, role: user.role });
    const refreshToken = generateRefreshToken({ id: user.id });

    logger.info('User registered', { userId: user.id, email });

    return created(res, {
      user: { id: user.id, username: user.username, email: user.email, role: user.role },
      accessToken,
      refreshToken,
    }, 'Registration successful');
  } catch (err) {
    next(err);
  }
};

const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ where: { email } });
    if (!user) return unauthorized(res, 'Invalid credentials');

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return unauthorized(res, 'Invalid credentials');

    const accessToken = generateAccessToken({ id: user.id, role: user.role });
    const refreshToken = generateRefreshToken({ id: user.id });

    logger.info('User logged in', { userId: user.id });

    return success(res, {
      user: { id: user.id, username: user.username, email: user.email, role: user.role },
      accessToken,
      refreshToken,
    }, 'Login successful');
  } catch (err) {
    next(err);
  }
};

const logout = async (req, res) => {
  return success(res, null, 'Logged out successfully');
};

const getProfile = async (req, res, next) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: ['id', 'username', 'email', 'role', 'created_at'],
    });
    return success(res, { user });
  } catch (err) {
    next(err);
  }
};

module.exports = { register, login, logout, getProfile };
