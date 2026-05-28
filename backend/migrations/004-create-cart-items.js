'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('cart_items', {
      id: { type: Sequelize.UUID, primaryKey: true, allowNull: false },
      cart_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'carts', key: 'id' },
        onDelete: 'CASCADE',
      },
      product_id: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'products', key: 'id' },
      },
      quantity: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 1 },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.fn('NOW') },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.fn('NOW') },
    });
    await queryInterface.addIndex('cart_items', ['cart_id']);
    await queryInterface.addIndex('cart_items', ['cart_id', 'product_id'], { unique: true });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('cart_items');
  },
};
