const renderCart = (cartData) => {
  const container = document.getElementById('cart-items');
  const emptyMsg = document.getElementById('cart-empty');
  const summary = document.getElementById('cart-summary');
  if (!container) return;

  container.textContent = '';

  if (!cartData.items || cartData.items.length === 0) {
    if (emptyMsg) emptyMsg.style.display = 'block';
    if (summary) summary.style.display = 'none';
    return;
  }

  if (emptyMsg) emptyMsg.style.display = 'none';
  if (summary) summary.style.display = 'block';

  cartData.items.forEach((item) => {
    const div = document.createElement('div');
    div.className = 'cart-item';
    div.setAttribute('data-item-id', item.id);

    const img = document.createElement('img');
    img.src = item.product.image_url || 'https://via.placeholder.com/72x72?text=?';
    img.alt = item.product.name;
    div.appendChild(img);

    const info = document.createElement('div');
    info.className = 'cart-item-info';

    const name = document.createElement('div');
    name.className = 'cart-item-name';
    name.textContent = item.product.name;
    info.appendChild(name);

    const price = document.createElement('div');
    price.className = 'cart-item-price';
    price.textContent = `$${parseFloat(item.product.price).toFixed(2)} each`;
    info.appendChild(price);

    div.appendChild(info);

    const qtyCtrl = document.createElement('div');
    qtyCtrl.className = 'qty-control';

    const minusBtn = document.createElement('button');
    minusBtn.className = 'qty-btn';
    minusBtn.textContent = '-';
    minusBtn.addEventListener('click', () => changeQty(item.id, item.quantity - 1));

    const qtySpan = document.createElement('input');
    qtySpan.className = 'qty-input';
    qtySpan.type = 'number';
    qtySpan.min = '1';
    qtySpan.value = item.quantity;
    qtySpan.addEventListener('change', (e) => changeQty(item.id, parseInt(e.target.value)));

    const plusBtn = document.createElement('button');
    plusBtn.className = 'qty-btn';
    plusBtn.textContent = '+';
    plusBtn.addEventListener('click', () => changeQty(item.id, item.quantity + 1));

    qtyCtrl.appendChild(minusBtn);
    qtyCtrl.appendChild(qtySpan);
    qtyCtrl.appendChild(plusBtn);
    div.appendChild(qtyCtrl);

    const subtotal = document.createElement('div');
    subtotal.style.fontWeight = '600';
    subtotal.style.minWidth = '80px';
    subtotal.style.textAlign = 'right';
    subtotal.textContent = `$${(parseFloat(item.product.price) * item.quantity).toFixed(2)}`;
    div.appendChild(subtotal);

    const removeBtn = document.createElement('button');
    removeBtn.className = 'btn btn-outline btn-sm';
    removeBtn.textContent = 'Remove';
    removeBtn.addEventListener('click', () => removeFromCart(item.id));
    div.appendChild(removeBtn);

    container.appendChild(div);
  });

  const totalEl = document.getElementById('cart-total');
  if (totalEl) totalEl.textContent = `$${parseFloat(cartData.total).toFixed(2)}`;

  const countEl = document.getElementById('item-count');
  if (countEl) countEl.textContent = cartData.items.length;
};

const changeQty = async (itemId, newQty) => {
  if (newQty < 1) { removeFromCart(itemId); return; }
  try {
    await cart.updateItem(itemId, newQty);
    loadCart();
  } catch (err) {
    showAlert(err.message || 'Failed to update quantity');
  }
};

const removeFromCart = async (itemId) => {
  try {
    await cart.removeItem(itemId);
    loadCart();
    updateCartBadge();
  } catch (err) {
    showAlert('Failed to remove item');
  }
};

const loadCart = async () => {
  try {
    const { data } = await cart.get();
    renderCart(data.cart || { items: [], total: 0 });
  } catch (err) {
    showAlert('Failed to load cart');
  }
};

document.addEventListener('DOMContentLoaded', () => {
  if (!requireAuth()) return;
  updateNavbar();
  loadCart();

  const clearBtn = document.getElementById('clear-cart-btn');
  if (clearBtn) {
    clearBtn.addEventListener('click', async () => {
      if (!confirm('Clear all items from cart?')) return;
      try {
        await cart.clear();
        loadCart();
        updateCartBadge();
      } catch (err) {
        showAlert('Failed to clear cart');
      }
    });
  }

  const checkoutBtn = document.getElementById('checkout-btn');
  if (checkoutBtn) {
    checkoutBtn.addEventListener('click', () => {
      window.location.href = '/pages/checkout.html';
    });
  }
});
