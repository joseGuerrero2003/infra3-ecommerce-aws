const { Cart, CartItem, Product, Order, OrderItem } = require('../models');
const { success, created, notFound, badRequest } = require('../utils/responseHelper');
const logger = require('../utils/logger');

const simulatePayment = () => {
  return { success: true, transaction_id: `TXN-${Date.now()}`, status: 'paid' };
};

const checkout = async (req, res, next) => {
  try {
    const { shipping_address, payment } = req.body;

    const cart = await Cart.findOne({
      where: { user_id: req.user.id },
      include: [{
        model: CartItem,
        as: 'items',
        include: [{ model: Product, as: 'product' }],
      }],
    });

    if (!cart || !cart.items.length) {
      return badRequest(res, 'Cart is empty');
    }

    for (const item of cart.items) {
      if (item.product.stock < item.quantity) {
        return badRequest(res, `Insufficient stock for ${item.product.name}`);
      }
    }

    const total = cart.items.reduce((sum, item) => {
      return sum + parseFloat(item.product.price) * item.quantity;
    }, 0);

    const paymentResult = simulatePayment();

    const order = await Order.create({
      user_id: req.user.id,
      total_amount: total.toFixed(2),
      status: 'processing',
      payment_status: paymentResult.status,
      shipping_address,
    });

    const orderItemsData = cart.items.map((item) => ({
      order_id: order.id,
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price: item.product.price,
    }));

    await OrderItem.bulkCreate(orderItemsData);

    for (const item of cart.items) {
      await item.product.update({ stock: item.product.stock - item.quantity });
    }

    await CartItem.destroy({ where: { cart_id: cart.id } });

    const fullOrder = await Order.findByPk(order.id, {
      include: [{ model: OrderItem, as: 'items', include: [{ model: Product, as: 'product', attributes: ['id', 'name', 'image_url'] }] }],
    });

    logger.info('Order created', { orderId: order.id, userId: req.user.id, total });

    return created(res, {
      order: fullOrder,
      transaction_id: paymentResult.transaction_id,
    }, 'Order placed successfully');
  } catch (err) {
    next(err);
  }
};

const listOrders = async (req, res, next) => {
  try {
    const orders = await Order.findAll({
      where: { user_id: req.user.id },
      order: [['created_at', 'DESC']],
      include: [{ model: OrderItem, as: 'items' }],
    });
    return success(res, { orders });
  } catch (err) {
    next(err);
  }
};

const getOrder = async (req, res, next) => {
  try {
    const order = await Order.findOne({
      where: { id: req.params.id, user_id: req.user.id },
      include: [{
        model: OrderItem,
        as: 'items',
        include: [{ model: Product, as: 'product', attributes: ['id', 'name', 'image_url', 'price'] }],
      }],
    });
    if (!order) return notFound(res, 'Order not found');
    return success(res, { order });
  } catch (err) {
    next(err);
  }
};

module.exports = { checkout, listOrders, getOrder };
