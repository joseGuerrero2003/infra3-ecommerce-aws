let currentPage = 1;
let currentCategory = '';
let currentSearch = '';

const renderProducts = (prods) => {
  const grid = document.getElementById('products-grid');
  if (!grid) return;

  grid.textContent = '';

  if (!prods.length) {
    const p = document.createElement('p');
    p.className = 'text-muted';
    p.textContent = 'No products found.';
    grid.appendChild(p);
    return;
  }

  prods.forEach((p) => {
    const card = document.createElement('div');
    card.className = 'product-card';

    const img = document.createElement('img');
    img.src = p.image_url || 'https://via.placeholder.com/400x300?text=No+Image';
    img.alt = p.name;
    img.loading = 'lazy';
    card.appendChild(img);

    const body = document.createElement('div');
    body.className = 'product-card-body';

    const category = document.createElement('div');
    category.className = 'product-card-category';
    category.textContent = p.category || 'General';
    body.appendChild(category);

    const title = document.createElement('div');
    title.className = 'product-card-title';
    title.textContent = p.name;
    body.appendChild(title);

    const price = document.createElement('div');
    price.className = 'product-card-price';
    price.textContent = `$${parseFloat(p.price).toFixed(2)}`;
    body.appendChild(price);

    card.appendChild(body);

    const footer = document.createElement('div');
    footer.className = 'product-card-footer';

    const stock = document.createElement('span');
    stock.style.fontSize = '0.8rem';
    stock.style.color = p.stock > 0 ? 'var(--success)' : 'var(--danger)';
    stock.textContent = p.stock > 0 ? `${p.stock} in stock` : 'Out of stock';
    footer.appendChild(stock);

    const btn = document.createElement('button');
    btn.className = 'btn btn-primary btn-sm';
    btn.textContent = 'Add to cart';
    btn.disabled = p.stock === 0;
    btn.addEventListener('click', () => addToCart(p.id, p.name, btn));
    footer.appendChild(btn);

    card.appendChild(footer);
    grid.appendChild(card);
  });
};

const renderPagination = (pagination) => {
  const container = document.getElementById('pagination');
  if (!container) return;
  container.textContent = '';

  for (let i = 1; i <= pagination.pages; i++) {
    const btn = document.createElement('button');
    btn.className = `page-btn${i === currentPage ? ' active' : ''}`;
    btn.textContent = i;
    btn.addEventListener('click', () => { currentPage = i; loadProducts(); });
    container.appendChild(btn);
  }
};

const loadProducts = async () => {
  try {
    const params = { page: currentPage, limit: 12 };
    if (currentCategory) params.category = currentCategory;
    if (currentSearch) params.search = currentSearch;

    const { data } = await products.list(params);
    renderProducts(data.products);
    renderPagination(data.pagination);
  } catch (err) {
    showAlert('Failed to load products');
  }
};

const addToCart = async (productId, name, btn) => {
  if (!isLoggedIn()) { window.location.href = '/pages/login.html'; return; }
  btn.disabled = true;
  btn.textContent = 'Adding...';
  try {
    await cart.addItem(productId, 1);
    btn.textContent = 'Added!';
    showAlert(`${name} added to cart`, 'success');
    updateCartBadge();
    setTimeout(() => { btn.textContent = 'Add to cart'; btn.disabled = false; }, 1500);
  } catch (err) {
    showAlert(err.message || 'Failed to add to cart');
    btn.textContent = 'Add to cart';
    btn.disabled = false;
  }
};

document.addEventListener('DOMContentLoaded', () => {
  updateNavbar();
  updateCartBadge();
  loadProducts();

  const searchInput = document.getElementById('search-input');
  if (searchInput) {
    let timeout;
    searchInput.addEventListener('input', (e) => {
      clearTimeout(timeout);
      timeout = setTimeout(() => {
        currentSearch = e.target.value.trim();
        currentPage = 1;
        loadProducts();
      }, 400);
    });
  }

  const categorySelect = document.getElementById('category-select');
  if (categorySelect) {
    categorySelect.addEventListener('change', (e) => {
      currentCategory = e.target.value;
      currentPage = 1;
      loadProducts();
    });
  }
});
