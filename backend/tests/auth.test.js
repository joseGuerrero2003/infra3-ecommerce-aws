require('./setup');
const request = require('supertest');
const createApp = require('../src/config/app');
const { sequelize, User, Cart, CartItem } = require('../src/models');

const app = createApp();

beforeAll(async () => {
  await sequelize.sync({ force: true });
});

afterAll(async () => {
  await sequelize.close();
});

afterEach(async () => {
  await CartItem.destroy({ where: {}, truncate: true }).catch(() => {});
  await Cart.destroy({ where: {}, truncate: true });
  await User.destroy({ where: {}, truncate: true });
});

describe('POST /api/auth/register', () => {
  it('registers a new user and returns tokens', async () => {
    const res = await request(app).post('/api/auth/register').send({
      username: 'testuser',
      email: 'test@example.com',
      password: 'Password1',
    });
    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toHaveProperty('accessToken');
    expect(res.body.data.user.email).toBe('test@example.com');
  });

  it('rejects duplicate email', async () => {
    await request(app).post('/api/auth/register').send({
      username: 'user1', email: 'dup@example.com', password: 'Password1',
    });
    const res = await request(app).post('/api/auth/register').send({
      username: 'user2', email: 'dup@example.com', password: 'Password1',
    });
    expect(res.statusCode).toBe(409);
  });

  it('rejects weak password', async () => {
    const res = await request(app).post('/api/auth/register').send({
      username: 'user3', email: 'weak@example.com', password: 'weak',
    });
    expect(res.statusCode).toBe(400);
  });
});

describe('POST /api/auth/login', () => {
  beforeEach(async () => {
    await request(app).post('/api/auth/register').send({
      username: 'loginuser', email: 'login@example.com', password: 'Password1',
    });
  });

  it('logs in with valid credentials', async () => {
    const res = await request(app).post('/api/auth/login').send({
      email: 'login@example.com', password: 'Password1',
    });
    expect(res.statusCode).toBe(200);
    expect(res.body.data).toHaveProperty('accessToken');
  });

  it('rejects invalid password', async () => {
    const res = await request(app).post('/api/auth/login').send({
      email: 'login@example.com', password: 'WrongPass1',
    });
    expect(res.statusCode).toBe(401);
  });
});

describe('GET /api/auth/profile', () => {
  it('returns profile for authenticated user', async () => {
    const reg = await request(app).post('/api/auth/register').send({
      username: 'profileuser', email: 'profile@example.com', password: 'Password1',
    });
    const token = reg.body.data.accessToken;

    const res = await request(app)
      .get('/api/auth/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.data.user.email).toBe('profile@example.com');
  });

  it('returns 401 without token', async () => {
    const res = await request(app).get('/api/auth/profile');
    expect(res.statusCode).toBe(401);
  });
});
