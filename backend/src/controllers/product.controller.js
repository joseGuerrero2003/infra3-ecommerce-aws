const { Op } = require('sequelize');
const { Product } = require('../models');
const { success, created, notFound, error } = require('../utils/responseHelper');

const list = async (req, res, next) => {
  try {
    const { page = 1, limit = 12, category, search } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const where = { is_active: true };
    if (category) where.category = category;
    if (search) where.name = { [Op.iLike]: `%${search}%` };

    const { count, rows } = await Product.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order: [['created_at', 'DESC']],
    });

    return success(res, {
      products: rows,
      pagination: {
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(count / parseInt(limit)),
      },
    });
  } catch (err) {
    next(err);
  }
};

const getOne = async (req, res, next) => {
  try {
    const product = await Product.findOne({
      where: { id: req.params.id, is_active: true },
    });
    if (!product) return notFound(res, 'Product not found');
    return success(res, { product });
  } catch (err) {
    next(err);
  }
};

const create = async (req, res, next) => {
  try {
    const { name, description, price, stock, image_url, category } = req.body;
    const product = await Product.create({ name, description, price, stock, image_url, category });
    return created(res, { product }, 'Product created');
  } catch (err) {
    next(err);
  }
};

const update = async (req, res, next) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return notFound(res, 'Product not found');

    const { name, description, price, stock, image_url, category, is_active } = req.body;
    await product.update({ name, description, price, stock, image_url, category, is_active });
    return success(res, { product }, 'Product updated');
  } catch (err) {
    next(err);
  }
};

const remove = async (req, res, next) => {
  try {
    const product = await Product.findByPk(req.params.id);
    if (!product) return notFound(res, 'Product not found');
    await product.update({ is_active: false });
    return success(res, null, 'Product deleted');
  } catch (err) {
    next(err);
  }
};

module.exports = { list, getOne, create, update, remove };
