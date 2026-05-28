require('./setup');
const request = require('supertest');
const createApp = require('../src/config/app');
const { sequelize, User, Product, Cart } = require('../src/models');

const app = createApp();

let adminToken;

beforeAll(async () => {
  await sequelize.sync({ force: true });
  const res = await request(app).post('/api/auth/register').send({
    username: 'admintest', email: 'admin@test.com', password: 'Password1',
  });
  await User.update({ role: 'admin' }, { where: { email: 'admin@test.com' } });
  const login = await request(app).post('/api/auth/login').send({
    email: 'admin@test.com', password: 'Password1',
  });
  adminToken = login.body.data.accessToken;
});

afterAll(async () => {
  await sequelize.close();
});

describe('GET /api/products', () => {
  it('returns product list with pagination', async () => {
    const res = await request(app).get('/api/products');
    expect(res.statusCode).toBe(200);
    expect(res.body.data).toHaveProperty('products');
    expect(res.body.data).toHaveProperty('pagination');
  });
});

describe('POST /api/products', () => {
  it('admin can create product', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Test Product', price: 99.99, stock: 10, category: 'Test' });
    expect(res.statusCode).toBe(201);
    expect(res.body.data.product.name).toBe('Test Product');
  });

  it('non-admin cannot create product', async () => {
    const reg = await request(app).post('/api/auth/register').send({
      username: 'regular', email: 'regular@test.com', password: 'Password1',
    });
    const token = reg.body.data.accessToken;
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'Hack', price: 1, stock: 1 });
    expect(res.statusCode).toBe(403);
  });
});
