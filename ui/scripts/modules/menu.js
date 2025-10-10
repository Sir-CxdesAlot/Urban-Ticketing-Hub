/**
 * Menu and Service Navigation Module
 * Handles service menu toggle and switching between different service views
 * Includes role-based access control for menu items
 */

(function() {
    'use strict';

    // DOM Elements
    const menuToggle = document.getElementById('menuToggle');
    const serviceMenu = document.getElementById('serviceMenu');
    const serviceMenuItems = document.querySelectorAll('.service-menu-item');
    const serviceViews = document.querySelectorAll('.service-view');
    const loginBtn = document.getElementById('loginBtn');

    // Service role requirements
    const SERVICE_REQUIREMENTS = {
        passenger: { minRole: 'PASSENGER', permission: null },
        transport: { minRole: 'GUEST', permission: 'VIEW_PUBLIC_ROUTES' },
        ticketing: { minRole: 'PASSENGER', permission: 'VIEW_OWN_TICKETS' },
        payment: { minRole: 'PASSENGER', permission: 'PROCESS_PAYMENTS' },
        notification: { minRole: 'PASSENGER', permission: 'RECEIVE_NOTIFICATIONS' },
        admin: { minRole: 'TRANSPORT_MANAGER', permission: 'VIEW_TRANSPORT_ANALYTICS' }
    };

    /**
     * Check if user has access to a service
     * @param {string} serviceName - The name of the service to check
     * @returns {boolean} - True if user has access
     */
    function hasServiceAccess(serviceName) {
        const api = window.App?.api || window.APIModule;
        if (!api) return true; // Allow if API not loaded

        const requirement = SERVICE_REQUIREMENTS[serviceName];
        if (!requirement) return true; // Allow if no requirement defined

        // Check minimum role
        if (requirement.minRole && !api.hasMinimumRole(requirement.minRole)) {
            return false;
        }

        // Check specific permission
        if (requirement.permission && !api.hasPermission(requirement.permission)) {
            return false;
        }

        return true;
    }

    /**
     * Update menu visibility based on user role
     */
    function updateMenuVisibility() {
        serviceMenuItems.forEach(item => {
            const serviceName = item.dataset.service;
            const hasAccess = hasServiceAccess(serviceName);
            
            const listItem = item.parentElement;
            if (hasAccess) {
                listItem.removeAttribute('hidden');
                listItem.style.display = '';
            } else {
                listItem.setAttribute('hidden', '');
                listItem.style.display = 'none';
            }
        });
    }

    // Create overlay for mobile menu
    const overlay = document.createElement('div');
    overlay.className = 'menu-overlay';
    document.body.appendChild(overlay);

    /**
     * Toggle service menu visibility
     */
    function toggleMenu() {
        const isExpanded = menuToggle.getAttribute('aria-expanded') === 'true';
        
        if (isExpanded) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    /**
     * Open service menu
     */
    function openMenu() {
        menuToggle.setAttribute('aria-expanded', 'true');
        serviceMenu.hidden = false;
        overlay.classList.add('active');
        document.body.style.overflow = 'hidden'; // Prevent scrolling when menu is open
    }

    /**
     * Close service menu
     */
    function closeMenu() {
        menuToggle.setAttribute('aria-expanded', 'false');
        serviceMenu.hidden = true;
        overlay.classList.remove('active');
        document.body.style.overflow = '';
    }

    /**
     * Switch to a different service view
     * @param {string} serviceName - The name of the service to switch to
     */
    function switchService(serviceName) {
        // Update menu items
        serviceMenuItems.forEach(item => {
            if (item.dataset.service === serviceName) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });

        // Update service views
        serviceViews.forEach(view => {
            if (view.id === `${serviceName}View`) {
                view.classList.add('active');
            } else {
                view.classList.remove('active');
            }
        });

        // Close menu on mobile after selection
        closeMenu();

        // Initialize service-specific functionality
        if (serviceName === 'passenger') {
            // Initialize passenger view - load routes
            if (window.App && window.App.routeBrowser && window.App.routeBrowser.displayRoutes) {
                window.App.routeBrowser.displayRoutes();
            }
        } else if (serviceName === 'transport') {
            // Initialize transport view if available
            if (window.App && window.App.transport && window.App.transport.initTransportView) {
                window.App.transport.initTransportView();
            }
        } else if (serviceName === 'ticketing') {
            // Initialize ticketing view if available
            if (window.App && window.App.ticketing && window.App.ticketing.initTicketingView) {
                window.App.ticketing.initTicketingView();
            }
        } else if (serviceName === 'payment') {
            // Initialize payment view if available
            if (window.App && window.App.payment && window.App.payment.initPaymentView) {
                window.App.payment.initPaymentView();
            }
        } else if (serviceName === 'notification') {
            // Initialize notification view if available
            if (window.App && window.App.notification && window.App.notification.initNotificationView) {
                window.App.notification.initNotificationView();
            }
        } else if (serviceName === 'admin') {
            // Initialize admin view if available
            if (typeof AdminModule !== 'undefined' && typeof AdminModule.initAdminView === 'function') {
                AdminModule.initAdminView();
            }
        }

        // Update page title
        const serviceTitles = {
            passenger: 'Passenger Portal',
            transport: 'Transport Service',
            ticketing: 'Ticketing Service',
            payment: 'Payment Service',
            notification: 'Notification Service',
            admin: 'Admin Portal'
        };

        document.title = `${serviceTitles[serviceName]} - Windhoek Ticketing Platform`;
    }

    /**
     * Handle login button click
     */
    function handleLogin() {
        // TODO: Implement login modal/redirect
        console.log('Login clicked');
        alert('Login functionality will be implemented. Use the CLI tools for now.');
    }

    /**
     * Initialize menu functionality
     */
    function init() {
        // Update menu visibility based on current role
        updateMenuVisibility();

        // Menu toggle button
        if (menuToggle) {
            menuToggle.addEventListener('click', toggleMenu);
        }

        // Overlay click to close menu
        overlay.addEventListener('click', closeMenu);

        // Service menu items
        serviceMenuItems.forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                const serviceName = item.dataset.service;
                switchService(serviceName);
            });
        });

        // Login button
        if (loginBtn) {
            loginBtn.addEventListener('click', handleLogin);
        }

        // Handle browser back/forward with hash navigation
        window.addEventListener('hashchange', () => {
            const hash = window.location.hash.slice(1);
            if (hash && document.getElementById(`${hash}View`)) {
                switchService(hash);
            }
        });

        // Load service from URL hash on page load
        const initialHash = window.location.hash.slice(1);
        if (initialHash && document.getElementById(`${initialHash}View`)) {
            switchService(initialHash);
        } else {
            // Default to passenger view and load routes
            switchService('passenger');
        }

        // Close menu on escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && !serviceMenu.hidden) {
                closeMenu();
            }
        });

        console.log('Menu module initialized');
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Export functions for external use
    window.MenuModule = {
        switchService,
        toggleMenu,
        openMenu,
        closeMenu,
        updateMenuVisibility,
        hasServiceAccess
    };
})();
