/**
 * Permission-Based UI Rendering Module
 * Handles conditional rendering of UI elements based on user roles and permissions
 */

(function() {
    'use strict';

    /**
     * Check if an element should be visible based on role/permission requirements
     * @param {HTMLElement} element - The element to check
     * @returns {boolean} - True if element should be visible
     */
    function shouldShowElement(element) {
        const api = window.App?.api || window.APIModule;
        if (!api) return true; // Show everything if API not loaded

        // Check for required permission
        const requiredPermission = element.dataset.requiresPermission;
        if (requiredPermission && !api.hasPermission(requiredPermission)) {
            return false;
        }

        // Check for required role
        const requiredRole = element.dataset.requiresRole;
        if (requiredRole && !api.hasMinimumRole(requiredRole)) {
            return false;
        }

        // Check for required role level
        const requiredLevel = element.dataset.requiresLevel;
        if (requiredLevel && !api.hasRoleLevel(parseInt(requiredLevel))) {
            return false;
        }

        // Check for guest mode restriction
        const guestRestricted = element.dataset.guestRestricted === 'true';
        if (guestRestricted && api.session.guestMode) {
            return false;
        }

        // Check for logged-in only
        const requiresLogin = element.dataset.requiresLogin === 'true';
        if (requiresLogin && !api.session.loggedIn) {
            return false;
        }

        return true;
    }

    /**
     * Apply permission-based visibility to all marked elements
     */
    function applyPermissionBasedUI() {
        // Find all elements with permission/role requirements
        const elements = document.querySelectorAll([
            '[data-requires-permission]',
            '[data-requires-role]',
            '[data-requires-level]',
            '[data-guest-restricted]',
            '[data-requires-login]'
        ].join(','));

        elements.forEach(element => {
            const shouldShow = shouldShowElement(element);
            
            if (shouldShow) {
                element.removeAttribute('hidden');
                element.style.display = '';
                element.classList.remove('permission-hidden');
            } else {
                element.setAttribute('hidden', '');
                element.classList.add('permission-hidden');
            }
        });
    }

    /**
     * Apply permission-based disabled state to buttons/inputs
     */
    function applyPermissionBasedDisabled() {
        const elements = document.querySelectorAll([
            '[data-disable-permission]',
            '[data-disable-role]'
        ].join(','));

        const api = window.App?.api || window.APIModule;
        if (!api) return;

        elements.forEach(element => {
            const disablePermission = element.dataset.disablePermission;
            const disableRole = element.dataset.disableRole;

            let shouldDisable = false;

            if (disablePermission && !api.hasPermission(disablePermission)) {
                shouldDisable = true;
            }

            if (disableRole && !api.hasMinimumRole(disableRole)) {
                shouldDisable = true;
            }

            if (shouldDisable) {
                element.disabled = true;
                element.classList.add('permission-disabled');
                element.title = element.dataset.disabledMessage || 'You don\'t have permission for this action';
            } else {
                element.disabled = false;
                element.classList.remove('permission-disabled');
                element.title = element.dataset.originalTitle || '';
            }
        });
    }

    /**
     * Show guest prompt modal for restricted actions
     * @param {string} action - The action that requires login
     */
    function showGuestPrompt(action = 'perform this action') {
        const api = window.App?.api || window.APIModule;
        if (!api || !api.session.guestMode) return;

        const message = `You need to create an account to ${action}. Would you like to register now?`;
        
        if (confirm(message)) {
            // Open registration modal if available
            if (window.App?.modals) {
                window.App.modals.open('register');
            } else if (window.Modals) {
                window.Modals.open('register');
            }
        }
    }

    /**
     * Attach guest prompt handlers to elements
     */
    function attachGuestPromptHandlers() {
        const elements = document.querySelectorAll('[data-guest-prompt]');

        elements.forEach(element => {
            const action = element.dataset.guestPrompt || 'perform this action';
            
            element.addEventListener('click', (e) => {
                const api = window.App?.api || window.APIModule;
                if (api && api.session.guestMode) {
                    e.preventDefault();
                    e.stopPropagation();
                    showGuestPrompt(action);
                }
            });
        });
    }

    /**
     * Get role-specific content
     * @param {string} contentKey - The content key to retrieve
     * @returns {string} - The role-specific content
     */
    function getRoleSpecificContent(contentKey) {
        const api = window.App?.api || window.APIModule;
        if (!api) return '';

        const role = api.session.userRole || 'GUEST';
        const roleData = api.ROLES?.[role];

        const contentMap = {
            welcomeMessage: {
                GUEST: 'Welcome! Browse our routes and services.',
                PASSENGER: 'Welcome back! Ready to plan your next trip?',
                ROUTE_OPERATOR: 'Welcome, Operator. Check your assigned routes.',
                TRANSPORT_MANAGER: 'Welcome, Manager. View your transport analytics.',
                SUPER_ADMIN: 'Welcome, Administrator. System overview available.'
            },
            dashboardTitle: {
                GUEST: 'Explore Public Transport',
                PASSENGER: 'My Dashboard',
                ROUTE_OPERATOR: 'Operator Dashboard',
                TRANSPORT_MANAGER: 'Transport Management',
                SUPER_ADMIN: 'System Administration'
            },
            primaryAction: {
                GUEST: 'Create Account',
                PASSENGER: 'Purchase Tickets',
                ROUTE_OPERATOR: 'Validate Tickets',
                TRANSPORT_MANAGER: 'Manage Routes',
                SUPER_ADMIN: 'System Settings'
            }
        };

        return contentMap[contentKey]?.[role] || '';
    }

    /**
     * Update role-specific content in the UI
     */
    function updateRoleSpecificContent() {
        const elements = document.querySelectorAll('[data-role-content]');

        elements.forEach(element => {
            const contentKey = element.dataset.roleContent;
            const content = getRoleSpecificContent(contentKey);
            
            if (content) {
                element.textContent = content;
            }
        });
    }

    /**
     * Initialize permission-based UI
     */
    function init() {
        applyPermissionBasedUI();
        applyPermissionBasedDisabled();
        attachGuestPromptHandlers();
        updateRoleSpecificContent();

        console.log('Permission-based UI initialized');
    }

    /**
     * Refresh all permission-based UI elements
     */
    function refresh() {
        init();
        
        // Also update menu visibility
        if (window.MenuModule && window.MenuModule.updateMenuVisibility) {
            window.MenuModule.updateMenuVisibility();
        }

        // Update role badge
        if (window.App?.roleBadge) {
            window.App.roleBadge.update();
        }

        // Update guest banner
        if (window.App?.guestBanner) {
            window.App.guestBanner.update();
        }
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Export to global scope
    const PermissionsModule = {
        shouldShowElement,
        applyPermissionBasedUI,
        applyPermissionBasedDisabled,
        showGuestPrompt,
        getRoleSpecificContent,
        updateRoleSpecificContent,
        refresh,
        init
    };

    window.PermissionsModule = PermissionsModule;
    if (window.App) {
        window.App.permissions = PermissionsModule;
    }
})();
