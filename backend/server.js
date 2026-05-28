require('dotenv').config();
const { Sequelize } = require('sequelize');
const createApp = require('./src/config/app');
const logger = require('./src/utils/logger');
const dbConfig = require('./src/config/database');

const PORT = process.env.PORT || 3000;
const ENV = process.env.NODE_ENV || 'development';

const sequelize = new Sequelize(
  dbConfig[ENV].database,
  dbConfig[ENV].username,
  dbConfig[ENV].password,
  {
    host: dbConfig[ENV].host,
    port: dbConfig[ENV].port,
    dialect: dbConfig[ENV].dialect,
    logging: dbConfig[ENV].logging,
    pool: dbConfig[ENV].pool,
    dialectOptions: dbConfig[ENV].dialectOptions || {},
  }
);

const start = async () => {
  try {
    await sequelize.authenticate();
    logger.info('Database connection established');

    const app = createApp();

    app.listen(PORT, '0.0.0.0', () => {
      logger.info(`Server running on port ${PORT} [${ENV}]`);
    });
  } catch (err) {
    logger.error('Failed to start server', { error: err.message });
    process.exit(1);
  }
};

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

start();
