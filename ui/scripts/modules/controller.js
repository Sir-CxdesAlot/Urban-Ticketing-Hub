// Main controller for Windhoek Ticketing Platform
(() => {
  const App = (window.App = window.App || {});
  const { initTheme, toggleTheme } = App.theme || {};

  // Modal Management
  const Modals = {
    login: null,
    register: null,
    ticket: null,
    currentTrip: null, // Store trip data for ticket purchase

    init() {
      this.login = document.getElementById('loginModal');
      this.register = document.getElementById('registerModal');
      this.ticket = document.getElementById('ticketModal');
      
      // Close buttons
      document.getElementById('closeLoginModal')?.addEventListener('click', () => this.close('login'));
      document.getElementById('closeRegisterModal')?.addEventListener('click', () => this.close('register'));
      document.getElementById('closeTicketModal')?.addEventListener('click', () => this.close('ticket'));
      
      // Cancel buttons
      document.getElementById('cancelLoginBtn')?.addEventListener('click', () => this.close('login'));
      document.getElementById('cancelRegisterBtn')?.addEventListener('click', () => this.close('register'));
      document.getElementById('cancelTicketBtn')?.addEventListener('click', () => this.close('ticket'));
      
      // Overlays
      document.getElementById('loginOverlay')?.addEventListener('click', () => this.close('login'));
      document.getElementById('registerOverlay')?.addEventListener('click', () => this.close('register'));
      document.getElementById('ticketOverlay')?.addEventListener('click', () => this.close('ticket'));
      
      // Switch between login/register
      document.getElementById('showRegisterLink')?.addEventListener('click', (e) => {
        e.preventDefault();
        this.close('login');
        this.open('register');
      });
      document.getElementById('showLoginLink')?.addEventListener('click', (e) => {
        e.preventDefault();
        this.close('register');
        this.open('login');
      });
      
      // Form submissions
      this.initForms();
    },

    open(modalName) {
      const modal = this[modalName];
      if (modal) {
        modal.removeAttribute('hidden');
        document.body.style.overflow = 'hidden';
      }
    },

    close(modalName) {
      const modal = this[modalName];
      if (modal) {
        modal.setAttribute('hidden', '');
        document.body.style.overflow = '';
        // Clear any error messages
        this.clearError(modalName);
      }
    },

    showError(modalName, message) {
      const errorEl = document.getElementById(`${modalName}Error`);
      if (errorEl) {
        errorEl.textContent = message;
        errorEl.removeAttribute('hidden');
      }
    },

    clearError(modalName) {
      const errorEl = document.getElementById(`${modalName}Error`);
      if (errorEl) {
        errorEl.textContent = '';
        errorEl.setAttribute('hidden', '');
      }
    },

    showSuccess(modalName, message) {
      const successEl = document.getElementById(`${modalName}Success`);
      if (successEl) {
        successEl.textContent = message;
        successEl.removeAttribute('hidden');
      }
    },

    setLoading(modalName, isLoading) {
      const submitBtn = document.getElementById(`${modalName}SubmitBtn`);
      if (submitBtn) {
        submitBtn.disabled = isLoading;
        const textEl = submitBtn.querySelector('.btn-text');
        if (textEl) {
          textEl.textContent = isLoading ? 'Please wait...' : submitBtn.dataset.originalText || 'Submit';
        }
      }
    },

    initForms() {
      // Login form
      const loginForm = document.getElementById('loginForm');
      if (loginForm) {
        loginForm.addEventListener('submit', async (e) => {
          e.preventDefault();
          await this.handleLogin(new FormData(loginForm));
        });
      }

      // Register form
      const registerForm = document.getElementById('registerForm');
      if (registerForm) {
        registerForm.addEventListener('submit', async (e) => {
          e.preventDefault();
          await this.handleRegister(new FormData(registerForm));
        });
      }

      // Ticket form
      const ticketForm = document.getElementById('ticketForm');
      if (ticketForm) {
        ticketForm.addEventListener('submit', async (e) => {
          e.preventDefault();
          await this.handleTicketPurchase(new FormData(ticketForm));
        });
      }
    },

    async handleLogin(formData) {
      this.clearError('login');
      this.setLoading('login', true);

      const email = formData.get('email');
      const password = formData.get('password');

      try {
        const api = App.api || window.APIModule;
        const security = window.SecurityModule;
        if (!api) throw new Error('API module not loaded');

        // Check if account is locked
        if (security && security.isAccountLocked(email)) {
          throw new Error('Account temporarily locked due to multiple failed login attempts. Please try again later.');
        }

        const result = await api.passengerLogin(email, password);
        
        if (result.success) {
          // Track successful login
          if (security) {
            security.trackLoginAttempt(email, true);
            security.createAuditLog(security.AUDIT_TYPES.LOGIN_SUCCESS, {
              email: email,
              role: result.user?.role || 'PASSENGER'
            });
          }

          this.close('login');
          alert('Login successful! Welcome back, ' + (result.user?.firstName || 'User'));
          RoleBadge.update();
          GuestBanner.update();
          // Refresh permission-based UI
          if (window.PermissionsModule) {
            window.PermissionsModule.refresh();
          }
          window.location.reload(); // Reload to update UI
        } else {
          // Track failed login
          if (security) {
            security.trackLoginAttempt(email, false, result.message || 'Invalid credentials');
          }
          this.showError('login', result.message || 'Login failed');
        }
      } catch (error) {
        console.error('Login error:', error);
        
        // Track failed login attempt
        const security = window.SecurityModule;
        if (security) {
          security.trackLoginAttempt(email, false, error.message);
        }
        
        this.showError('login', error.message || 'An error occurred. Please try again.');
      } finally {
        this.setLoading('login', false);
      }
    },

    async handleRegister(formData) {
      this.clearError('register');
      this.setLoading('register', true);

      const data = {
        firstName: formData.get('firstName'),
        lastName: formData.get('lastName'),
        email: formData.get('email'),
        phone: formData.get('phone'),
        password: formData.get('password')
      };

      try {
        const api = App.api || window.APIModule;
        const security = window.SecurityModule;
        if (!api) throw new Error('API module not loaded');

        const result = await api.passengerRegister(data);
        
        if (result.success) {
          // Log successful registration
          if (security) {
            security.createAuditLog(security.AUDIT_TYPES.USER_CREATED, {
              email: data.email,
              firstName: data.firstName,
              lastName: data.lastName,
              phone: data.phone,
              role: 'PASSENGER'
            });
          }

          this.close('register');
          alert('Registration successful! Please log in.');
          this.open('login');
        } else {
          this.showError('register', result.message || 'Registration failed');
        }
      } catch (error) {
        console.error('Register error:', error);
        this.showError('register', error.message || 'An error occurred. Please try again.');
      } finally {
        this.setLoading('register', false);
      }
    },

    async handleTicketPurchase(formData) {
      this.clearError('ticket');
      this.setLoading('ticket', true);

      const quantity = parseInt(formData.get('quantity'));
      const paymentMethod = formData.get('paymentMethod');

      try {
        const api = App.api || window.APIModule;
        if (!api) throw new Error('API module not loaded');
        if (!api.session.loggedIn) {
          this.showError('ticket', 'You must be logged in to purchase tickets');
          return;
        }
        if (!this.currentTrip) {
          this.showError('ticket', 'No trip selected');
          return;
        }

        // Call ticket purchase API (to be implemented in api.js)
        const result = await api.purchaseTicket({
          tripId: this.currentTrip.id,
          quantity,
          paymentMethod
        });

        if (result.success) {
          this.showSuccess('ticket', 'Ticket purchased successfully!');
          setTimeout(() => {
            this.close('ticket');
            alert('Your ticket has been confirmed! Check your email for details.');
          }, 2000);
        } else {
          this.showError('ticket', result.message || 'Purchase failed');
        }
      } catch (error) {
        console.error('Ticket purchase error:', error);
        this.showError('ticket', error.message || 'An error occurred. Please try again.');
      } finally {
        this.setLoading('ticket', false);
      }
    },

    openTicketModal(trip) {
      this.currentTrip = trip;
      const detailsEl = document.getElementById('tripDetails');
      if (detailsEl) {
        detailsEl.innerHTML = `
          <h3>Trip Details</h3>
          <p><strong>Route:</strong> ${trip.routeName || 'N/A'}</p>
          <p><strong>Departure:</strong> ${trip.departureTime || 'N/A'}</p>
          <p><strong>Arrival:</strong> ${trip.arrivalTime || 'N/A'}</p>
          <p><strong>Price:</strong> N$${trip.price || '0.00'}</p>
          <p><strong>Available Seats:</strong> ${trip.availableSeats || 0}</p>
        `;
      }
      this.open('ticket');
    }
  };

  // Role Badge Management
  const RoleBadge = {
    badge: null,
    icon: null,
    label: null,

    init() {
      this.badge = document.getElementById('roleBadge');
      this.icon = this.badge?.querySelector('.role-icon');
      this.label = this.badge?.querySelector('.role-label');
      this.update();
    },

    update() {
      const api = App.api || window.APIModule;
      if (!api || !this.badge) return;

      const role = api.session.userRole || 'GUEST';
      const roleData = api.ROLES?.[role] || {
        label: 'Guest',
        icon: '👁️',
        level: 1
      };

      // Update badge content
      if (this.icon) this.icon.textContent = roleData.icon;
      if (this.label) this.label.textContent = roleData.label;

      // Update badge classes
      this.badge.className = 'role-badge';
      if (api.session.guestMode) {
        this.badge.classList.add('guest-mode');
      } else {
        this.badge.classList.add(role.toLowerCase().replace('_', '-'));
      }

      // Update title
      this.badge.title = `Current role: ${roleData.label} (Level ${roleData.level})`;
    }
  };

  // Guest Banner Management
  const GuestBanner = {
    banner: null,
    registerBtn: null,
    loginBtn: null,

    init() {
      this.banner = document.getElementById('guestBanner');
      this.registerBtn = document.getElementById('guestRegisterBtn');
      this.loginBtn = document.getElementById('guestLoginBtn');

      // Event listeners
      if (this.registerBtn) {
        this.registerBtn.addEventListener('click', () => {
          Modals.open('register');
        });
      }

      if (this.loginBtn) {
        this.loginBtn.addEventListener('click', () => {
          Modals.open('login');
        });
      }

      this.update();
    },

    update() {
      const api = App.api || window.APIModule;
      if (!api || !this.banner) return;

      if (api.session.guestMode) {
        this.show();
      } else {
        this.hide();
      }
    },

    show() {
      if (this.banner) {
        this.banner.removeAttribute('hidden');
      }
    },

    hide() {
      if (this.banner) {
        this.banner.setAttribute('hidden', '');
      }
    }
  };

  // Initialize application when DOM is ready
  document.addEventListener('DOMContentLoaded', () => {
    console.log('Windhoek Ticketing Platform - Initializing...');
    
    // Initialize theme
    if (typeof initTheme === 'function') {
      initTheme();
      console.log('Theme initialized');
    }
    
    // Update footer year
    const yearNowEl = document.getElementById('yearNow');
    if (yearNowEl) {
      yearNowEl.textContent = String(new Date().getFullYear());
    }

    // Initialize modals
    Modals.init();
    console.log('Modals initialized');

    // Initialize role badge
    RoleBadge.init();
    console.log('Role badge initialized');

    // Initialize guest banner
    GuestBanner.init();
    console.log('Guest banner initialized');

    // Theme toggle button
    const themeBtn = document.getElementById('themeToggle');
    if (themeBtn && typeof toggleTheme === 'function') {
      themeBtn.addEventListener('click', () => {
        console.log('Theme toggle clicked!');
        toggleTheme();
      });
      console.log('Theme toggle event listener attached');
    }

    // Search functionality is handled by search.js module

    // Login/Logout button
    const loginBtn = document.getElementById('loginBtn');
    if (loginBtn) {
      const updateLoginButton = () => {
        const api = App.api || window.APIModule;
        if (api && api.session.loggedIn) {
          loginBtn.title = 'Logout (' + (api.session.user?.firstName || 'User') + ')';
          loginBtn.querySelector('img').alt = 'Logout';
        } else {
          loginBtn.title = 'Login';
          loginBtn.querySelector('img').alt = 'Login';
        }
      };

      loginBtn.addEventListener('click', () => {
        const api = App.api || window.APIModule;
        const security = window.SecurityModule;
        if (api && api.session.loggedIn) {
          if (confirm('Are you sure you want to logout?')) {
            // Log logout event before logging out
            if (security) {
              const email = api.session.user?.email;
              const role = api.session.user?.role;
              security.createAuditLog(security.AUDIT_TYPES.LOGOUT, {
                email: email,
                role: role,
                sessionDuration: Date.now() - (api.session.loginTime || Date.now())
              });
            }

            api.passengerLogout();
            updateLoginButton();
            RoleBadge.update();
            GuestBanner.update();
            // Refresh permission-based UI
            if (window.PermissionsModule) {
              window.PermissionsModule.refresh();
            }
            alert('You have been logged out successfully!');
          }
        } else {
          Modals.open('login');
        }
      });

      updateLoginButton();
    }

    // Expose Modals to global scope for use in other modules
    App.modals = Modals;
    App.roleBadge = RoleBadge;
    App.guestBanner = GuestBanner;
    window.Modals = Modals;

    console.log('Windhoek Ticketing Platform - Ready!');
    console.log('To test the API, ensure Docker services are running: docker-compose up');
  });
})();
