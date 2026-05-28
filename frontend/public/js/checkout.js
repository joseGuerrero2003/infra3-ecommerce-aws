document.addEventListener('DOMContentLoaded', async () => {
  if (!requireAuth()) return;
  updateNavbar();

  try {
    const { data } = await cart.get();
    const cartData = data.cart || { items: [], total: 0 };

    const summaryEl = document.getElementById('order-summary');
    if (summaryEl && cartData.items.length) {
      summaryEl.textContent = '';
      cartData.items.forEach((item) => {
        const row = document.createElement('div');
        row.style.cssText = 'display:flex;justify-content:space-between;margin-bottom:0.5rem;font-size:0.9rem;';

        const nameSpan = document.createElement('span');
        nameSpan.textContent = `${item.product.name} x${item.quantity}`;
        row.appendChild(nameSpan);

        const priceSpan = document.createElement('span');
        priceSpan.textContent = `$${(parseFloat(item.product.price) * item.quantity).toFixed(2)}`;
        row.appendChild(priceSpan);

        summaryEl.appendChild(row);
      });

      const totalRow = document.createElement('div');
      totalRow.className = 'cart-total';

      const totalLabel = document.createElement('span');
      totalLabel.textContent = 'Total';
      totalRow.appendChild(totalLabel);

      const totalVal = document.createElement('span');
      totalVal.textContent = `$${parseFloat(cartData.total).toFixed(2)}`;
      totalRow.appendChild(totalVal);

      summaryEl.appendChild(totalRow);
    }
  } catch (err) {
    showAlert('Failed to load cart summary');
  }

  const checkoutForm = document.getElementById('checkout-form');
  if (checkoutForm) {
    checkoutForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = checkoutForm.querySelector('[type="submit"]');
      btn.disabled = true;
      btn.textContent = 'Processing...';

      try {
        const { data } = await orders.checkout({
          shipping_address: {
            name: document.getElementById('ship-name').value,
            address: document.getElementById('ship-address').value,
            city: document.getElementById('ship-city').value,
            zip: document.getElementById('ship-zip').value,
            country: document.getElementById('ship-country').value,
          },
          payment: {
            card_number: document.getElementById('card-number').value,
            expiry: document.getElementById('card-expiry').value,
            cvv: document.getElementById('card-cvv').value,
          },
        });

        localStorage.setItem('lastOrderId', data.order.id);
        localStorage.setItem('lastTransactionId', data.transaction_id);
        window.location.href = '/pages/order-confirmation.html';
      } catch (err) {
        showAlert(err.message || 'Checkout failed');
        btn.disabled = false;
        btn.textContent = 'Place Order';
      }
    });
  }
});
