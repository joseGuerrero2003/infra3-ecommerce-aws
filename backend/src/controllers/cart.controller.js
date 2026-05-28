const { Cart, CartItem, Product } = require('../models');
const { success, notFound, badRequest, error } = require('../utils/responseHelper');

const getOrCreateCart = async (userId) => {
  let cart = await Cart.findOne({ where: { user_id: userId } });
  if (!cart) cart = await Cart.create({ user_id: userId });
  return cart;
};

const getCart = async (req, res, next) => {
  try {
    const cart = await Cart.findOne({
      where: { user_id: req.user.id },
      include: [{
        model: CartItem,
        as: 'items',
        include: [{ model: Product, as: 'product', attributes: ['id', 'name', 'price', 'image_url', 'stock'] }],
      }],
    });

    if (!cart) return success(res, { cart: { items: [], total: 0 } });

    const total = cart.items.reduce((sum, item) => {
      return sum + parseFloat(item.product.price) * item.quantity;
    }, 0);

    return success(res, { cart: { ...cart.toJSON(), total: total.toFixed(2) } });
  } catch (err) {
    next(err);
  }
};

const addItem = async (req, res, next) => {
  try {
    const { product_id, quantity } = req.body;

    const product = await Product.findOne({ where: { id: product_id, is_active: true } });
    if (!product) return notFound(res, 'Product not found');
    if (product.stock < quantity) return badRequest(res, 'Insufficient stock');

    const cart = await getOrCreateCart(req.user.id);

    const [item, created] = await CartItem.findOrCreate({
      where: { cart_id: cart.id, product_id },
      defaults: { quantity },
    });

    if (!created) {
      const newQty = item.quantity + quantity;
      if (product.stock < newQty) return badRequest(res, 'Insufficient stock');
      await item.update({ quantity: newQty });
    }

    return success(res, { item }, created ? 'Item added to cart' : 'Cart item updated');
  } catch (err) {
    next(err);
  }
};

const updateItem = async (req, res, next) => {
  try {
    const item = await CartItem.findOne({
      where: { id: req.params.id },
      include: [{ model: Product, as: 'product' }],
    });
    if (!item) return notFound(res, 'Cart item not found');

    const cart = await Cart.findByPk(item.cart_id);
    if (cart.user_id !== req.user.id) return error(res, 'Forbidden', 403);

    const { quantity } = req.body;
    if (item.product.stock < quantity) return badRequest(res, 'Insufficient stock');

    await item.update({ quantity });
    return success(res, { item }, 'Cart item updated');
  } catch (err) {
    next(err);
  }
};

const removeItem = async (req, res, next) => {
  try {
    const item = await CartItem.findByPk(req.params.id);
    if (!item) return notFound(res, 'Cart item not found');

    const cart = await Cart.findByPk(item.cart_id);
    if (cart.user_id !== req.user.id) return error(res, 'Forbidden', 403);

    await item.destroy();
    return success(res, null, 'Item removed from cart');
  } catch (err) {
    next(err);
  }
};

const clearCart = async (req, res, next) => {
  try {
    const cart = await Cart.findOne({ where: { user_id: req.user.id } });
    if (cart) await CartItem.destroy({ where: { cart_id: cart.id } });
    return success(res, null, 'Cart cleared');
  } catch (err) {
    next(err);
  }
};

module.exports = { getCart, addItem, updateItem, removeItem, clearCart };
