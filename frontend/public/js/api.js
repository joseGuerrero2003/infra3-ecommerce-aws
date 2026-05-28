const API_BASE = '/api';

const api = {
  _getToken() {
    return localStorage.getItem('accessToken');
  },

  _headers(extra = {}) {
    const h = { 'Content-Type': 'application/json', ...extra };
    const t = this._getToken();
    if (t) h['Authorization'] = `Bearer ${t}`;
    return h;
  },

  async _request(method, path, body = null) {
    const opts = { method, headers: this._headers() };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(`${API_BASE}${path}`, opts);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw { status: res.status, message: data.message || 'Request failed', data };
    return data;
  },

  get: (path) => api._request('GET', path),
  post: (path, body) => api._request('POST', path, body),
  put: (path, body) => api._request('PUT', path, body),
  delete: (path) => api._request('DELETE', path),
};

const auth = {
  register: (d) => api.post('/auth/register', d),
  login: (d) => api.post('/auth/login', d),
  logout: () => api.post('/auth/logout'),
  profile: () => api.get('/auth/profile'),
};

const products = {
  list: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return api.get(`/products${qs ? '?' + qs : ''}`);
  },
  get: (id) => api.get(`/products/${id}`),
  create: (d) => api.post('/products', d),
  update: (id, d) => api.put(`/products/${id}`, d),
  delete: (id) => api.delete(`/products/${id}`),
};

const cart = {
  get: () => api.get('/cart'),
  addItem: (product_id, quantity = 1) => api.post('/cart/items', { product_id, quantity }),
  updateItem: (id, quantity) => api.put(`/cart/items/${id}`, { quantity }),
  removeItem: (id) => api.delete(`/cart/items/${id}`),
  clear: () => api.delete('/cart'),
};

const orders = {
  checkout: (d) => api.post('/orders/checkout', d),
  list: () => api.get('/orders'),
  get: (id) => api.get(`/orders/${id}`),
};

const showAlert = (msg, type = 'danger', containerId = 'alert-container') => {
  const el = document.getElementById(containerId);
  if (!el) return;
  el.textContent = '';
  const div = document.createElement('div');
  div.className = `alert alert-${type}`;
  div.textContent = msg;
  el.appendChild(div);
  setTimeout(() => { el.textContent = ''; }, 5000);
};

const updateCartBadge = async () => {
  if (!localStorage.getItem('accessToken')) return;
  try {
    const { data } = await cart.get();
    const count = data.cart && data.cart.items ? data.cart.items.length : 0;
    document.querySelectorAll('.cart-count').forEach((el) => {
      el.textContent = count;
      el.style.display = count > 0 ? 'flex' : 'none';
    });
  } catch (_) {}
};

const isLoggedIn = () => !!localStorage.getItem('accessToken');

const requireAuth = () => {
  if (!isLoggedIn()) { window.location.href = '/pages/login.html'; return false; }
  return true;
};

const updateNavbar = () => {
  const loggedIn = isLoggedIn();
  document.querySelectorAll('.nav-auth').forEach((el) => {
    el.style.display = loggedIn ? 'none' : 'inline-flex';
  });
  document.querySelectorAll('.nav-user').forEach((el) => {
    el.style.display = loggedIn ? 'inline-flex' : 'none';
  });
  const username = localStorage.getItem('username');
  document.querySelectorAll('.nav-username').forEach((el) => {
    el.textContent = username || '';
  });
};
