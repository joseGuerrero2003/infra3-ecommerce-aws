const { Sequelize, DataTypes } = require('sequelize');
const dbConfig = require('../config/database');

const ENV = process.env.NODE_ENV || 'development';
const config = dbConfig[ENV];

const sequelize = new Sequelize(
  config.database,
  config.username,
  config.password,
  {
    host: config.host,
    port: config.port,
    dialect: config.dialect,
    logging: config.logging,
    pool: config.pool,
    dialectOptions: config.dialectOptions || {},
  }
);

const User = require('./user.model')(sequelize, DataTypes);
const Product = require('./product.model')(sequelize, DataTypes);
const Cart = require('./cart.model')(sequelize, DataTypes);
const CartItem = require('./cartItem.model')(sequelize, DataTypes);
const Order = require('./order.model')(sequelize, DataTypes);
const OrderItem = require('./orderItem.model')(sequelize, DataTypes);

User.hasOne(Cart, { foreignKey: 'user_id', as: 'cart' });
Cart.belongsTo(User, { foreignKey: 'user_id' });

Cart.hasMany(CartItem, { foreignKey: 'cart_id', as: 'items', onDelete: 'CASCADE' });
CartItem.belongsTo(Cart, { foreignKey: 'cart_id' });

CartItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
Product.hasMany(CartItem, { foreignKey: 'product_id' });

User.hasMany(Order, { foreignKey: 'user_id', as: 'orders' });
Order.belongsTo(User, { foreignKey: 'user_id' });

Order.hasMany(OrderItem, { foreignKey: 'order_id', as: 'items', onDelete: 'CASCADE' });
OrderItem.belongsTo(Order, { foreignKey: 'order_id' });

OrderItem.belongsTo(Product, { foreignKey: 'product_id', as: 'product' });
Product.hasMany(OrderItem, { foreignKey: 'product_id' });

module.exports = { sequelize, Sequelize, User, Product, Cart, CartItem, Order, OrderItem };
