document.addEventListener('DOMContentLoaded', () => {
  updateNavbar();

  const loginForm = document.getElementById('login-form');
  if (loginForm) {
    loginForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = loginForm.querySelector('[type="submit"]');
      btn.disabled = true;
      try {
        const { data } = await auth.login({
          email: document.getElementById('email').value,
          password: document.getElementById('password').value,
        });
        localStorage.setItem('accessToken', data.accessToken);
        localStorage.setItem('refreshToken', data.refreshToken);
        localStorage.setItem('username', data.user.username);
        localStorage.setItem('userId', data.user.id);
        localStorage.setItem('role', data.user.role);
        window.location.href = '/';
      } catch (err) {
        showAlert(err.message || 'Login failed');
        btn.disabled = false;
      }
    });
  }

  const registerForm = document.getElementById('register-form');
  if (registerForm) {
    registerForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const btn = registerForm.querySelector('[type="submit"]');
      const pwd = document.getElementById('password').value;
      const confirm = document.getElementById('confirm-password').value;
      if (pwd !== confirm) { showAlert('Passwords do not match'); return; }
      btn.disabled = true;
      try {
        const { data } = await auth.register({
          username: document.getElementById('username').value,
          email: document.getElementById('email').value,
          password: pwd,
        });
        localStorage.setItem('accessToken', data.accessToken);
        localStorage.setItem('refreshToken', data.refreshToken);
        localStorage.setItem('username', data.user.username);
        localStorage.setItem('userId', data.user.id);
        localStorage.setItem('role', data.user.role);
        window.location.href = '/';
      } catch (err) {
        showAlert(err.message || 'Registration failed');
        btn.disabled = false;
      }
    });
  }

  const logoutBtn = document.getElementById('logout-btn');
  if (logoutBtn) {
    logoutBtn.addEventListener('click', async (e) => {
      e.preventDefault();
      try { await auth.logout(); } catch (_) {}
      localStorage.clear();
      window.location.href = '/pages/login.html';
    });
  }
});
