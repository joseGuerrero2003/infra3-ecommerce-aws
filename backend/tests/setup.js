require('dotenv').config({ path: '.env.example' });

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-jwt-secret-min-32-chars-long!!';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret-min-32-chars!!';
process.env.JWT_EXPIRES_IN = '15m';
process.env.JWT_REFRESH_EXPIRES_IN = '7d';
process.env.DB_HOST = process.env.DB_HOST || 'localhost';
process.env.DB_NAME = process.env.DB_NAME || 'ecommerce_test';
process.env.DB_USER = process.env.DB_USER || 'dbadmin';
process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'changeme';
process.env.DB_PORT = process.env.DB_PORT || '5432';
process.env.PORT = '3001';
