/**
 * Security & Audit Module
 * Implements role-based authorization, audit logging, and session monitoring
 * Phase 4: Security & Testing
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});

    // Audit log storage
    const auditLog = [];
    const MAX_AUDIT_LOGS = 1000; // Keep last 1000 entries

    // Session monitoring
    const sessionMonitor = {
        lastActivity: Date.now(),
        loginAttempts: {},
        suspiciousActivity: []
    };

    // Security configuration
    const SECURITY_CONFIG = {
        sessionTimeout: 30 * 60 * 1000, // 30 minutes
        maxLoginAttempts: 5,
        lockoutDuration: 15 * 60 * 1000, // 15 minutes
        auditRetentionDays: 90,
        enforcePasswordPolicy: true,
        requireSecureConnection: false // Set true in production
    };

    /**
     * Audit Log Entry Types
     */
    const AUDIT_TYPES = {
        // Authentication
        LOGIN_SUCCESS: 'LOGIN_SUCCESS',
        LOGIN_FAILURE: 'LOGIN_FAILURE',
        LOGOUT: 'LOGOUT',
        SESSION_TIMEOUT: 'SESSION_TIMEOUT',
        
        // Authorization
        PERMISSION_GRANTED: 'PERMISSION_GRANTED',
        PERMISSION_DENIED: 'PERMISSION_DENIED',
        ROLE_CHANGE: 'ROLE_CHANGE',
        
        // User Actions
        USER_CREATED: 'USER_CREATED',
        USER_UPDATED: 'USER_UPDATED',
        USER_DELETED: 'USER_DELETED',
        
        // Ticket Operations
        TICKET_PURCHASED: 'TICKET_PURCHASED',
        TICKET_VALIDATED: 'TICKET_VALIDATED',
        TICKET_REFUNDED: 'TICKET_REFUNDED',
        
        // Route Operations
        ROUTE_CREATED: 'ROUTE_CREATED',
        ROUTE_UPDATED: 'ROUTE_UPDATED',
        ROUTE_DELETED: 'ROUTE_DELETED',
        
        // Security Events
        SECURITY_ALERT: 'SECURITY_ALERT',
        SUSPICIOUS_ACTIVITY: 'SUSPICIOUS_ACTIVITY',
        ACCOUNT_LOCKED: 'ACCOUNT_LOCKED',
        PASSWORD_CHANGED: 'PASSWORD_CHANGED',
        
        // System Events
        SYSTEM_ERROR: 'SYSTEM_ERROR',
        CONFIGURATION_CHANGED: 'CONFIGURATION_CHANGED'
    };

    /**
     * Create audit log entry
     */
    function createAuditLog(type, details = {}) {
        const api = window.App?.api || window.APIModule;
        
        const entry = {
            id: generateAuditId(),
            timestamp: new Date().toISOString(),
            type: type,
            userId: api?.session?.userId || 'anonymous',
            userRole: api?.session?.userRole || 'GUEST',
            userEmail: api?.session?.user?.email || 'N/A',
            ipAddress: 'client-side', // In production, get from backend
            userAgent: navigator.userAgent,
            details: details,
            sessionId: getSessionId()
        };

        // Add to audit log
        auditLog.unshift(entry);

        // Maintain max size
        if (auditLog.length > MAX_AUDIT_LOGS) {
            auditLog.pop();
        }

        // Persist critical events to localStorage
        if (isCriticalEvent(type)) {
            persistAuditLog(entry);
        }

        // Log to console in development
        if (isDevelopment()) {
            console.log(`[AUDIT] ${type}:`, entry);
        }

        return entry;
    }

    /**
     * Generate unique audit ID
     */
    function generateAuditId() {
        return `audit_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * Get session ID
     */
    function getSessionId() {
        let sessionId = sessionStorage.getItem('session_id');
        if (!sessionId) {
            sessionId = `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
            sessionStorage.setItem('session_id', sessionId);
        }
        return sessionId;
    }

    /**
     * Check if event is critical
     */
    function isCriticalEvent(type) {
        const criticalEvents = [
            AUDIT_TYPES.LOGIN_FAILURE,
            AUDIT_TYPES.PERMISSION_DENIED,
            AUDIT_TYPES.SECURITY_ALERT,
            AUDIT_TYPES.SUSPICIOUS_ACTIVITY,
            AUDIT_TYPES.ACCOUNT_LOCKED,
            AUDIT_TYPES.ROLE_CHANGE,
            AUDIT_TYPES.USER_DELETED,
            AUDIT_TYPES.CONFIGURATION_CHANGED
        ];
        return criticalEvents.includes(type);
    }

    /**
     * Persist audit log to localStorage
     */
    function persistAuditLog(entry) {
        try {
            const storedLogs = JSON.parse(localStorage.getItem('audit_logs') || '[]');
            storedLogs.unshift(entry);
            
            // Keep only last 100 critical events
            const trimmed = storedLogs.slice(0, 100);
            localStorage.setItem('audit_logs', JSON.stringify(trimmed));
        } catch (error) {
            console.error('Failed to persist audit log:', error);
        }
    }

    /**
     * Check if development environment
     */
    function isDevelopment() {
        return window.location.hostname === 'localhost' || 
               window.location.hostname === '127.0.0.1';
    }

    /**
     * Authorization middleware - check if user can perform action
     */
    function authorize(requiredPermission, action = 'perform this action') {
        const api = window.App?.api || window.APIModule;
        
        // Check if user has permission
        if (api && api.hasPermission && api.hasPermission(requiredPermission)) {
            createAuditLog(AUDIT_TYPES.PERMISSION_GRANTED, {
                permission: requiredPermission,
                action: action
            });
            return true;
        }

        // Permission denied
        createAuditLog(AUDIT_TYPES.PERMISSION_DENIED, {
            permission: requiredPermission,
            action: action,
            reason: 'Insufficient permissions'
        });

        return false;
    }

    /**
     * Check role authorization
     */
    function authorizeRole(requiredRole, action = 'access this feature') {
        const api = window.App?.api || window.APIModule;
        
        if (api && api.hasMinimumRole && api.hasMinimumRole(requiredRole)) {
            createAuditLog(AUDIT_TYPES.PERMISSION_GRANTED, {
                requiredRole: requiredRole,
                userRole: api.session?.userRole,
                action: action
            });
            return true;
        }

        createAuditLog(AUDIT_TYPES.PERMISSION_DENIED, {
            requiredRole: requiredRole,
            userRole: api.session?.userRole,
            action: action,
            reason: 'Insufficient role level'
        });

        return false;
    }

    /**
     * Track login attempt
     */
    function trackLoginAttempt(email, success, reason = '') {
        const attempts = sessionMonitor.loginAttempts[email] || {
            count: 0,
            lastAttempt: null,
            locked: false,
            lockoutExpiry: null
        };

        if (success) {
            // Reset on successful login
            delete sessionMonitor.loginAttempts[email];
            createAuditLog(AUDIT_TYPES.LOGIN_SUCCESS, {
                email: email,
                timestamp: new Date().toISOString()
            });
        } else {
            // Increment failed attempts
            attempts.count++;
            attempts.lastAttempt = Date.now();

            createAuditLog(AUDIT_TYPES.LOGIN_FAILURE, {
                email: email,
                attemptNumber: attempts.count,
                reason: reason,
                timestamp: new Date().toISOString()
            });

            // Check if should lock account
            if (attempts.count >= SECURITY_CONFIG.maxLoginAttempts) {
                attempts.locked = true;
                attempts.lockoutExpiry = Date.now() + SECURITY_CONFIG.lockoutDuration;
                
                createAuditLog(AUDIT_TYPES.ACCOUNT_LOCKED, {
                    email: email,
                    failedAttempts: attempts.count,
                    lockoutDuration: SECURITY_CONFIG.lockoutDuration,
                    lockoutExpiry: new Date(attempts.lockoutExpiry).toISOString()
                });

                flagSuspiciousActivity({
                    type: 'MULTIPLE_FAILED_LOGINS',
                    email: email,
                    attempts: attempts.count
                });
            }

            sessionMonitor.loginAttempts[email] = attempts;
        }

        return attempts;
    }

    /**
     * Check if account is locked
     */
    function isAccountLocked(email) {
        const attempts = sessionMonitor.loginAttempts[email];
        
        if (!attempts || !attempts.locked) {
            return false;
        }

        // Check if lockout expired
        if (Date.now() > attempts.lockoutExpiry) {
            delete sessionMonitor.loginAttempts[email];
            return false;
        }

        return true;
    }

    /**
     * Flag suspicious activity
     */
    function flagSuspiciousActivity(activity) {
        activity.timestamp = new Date().toISOString();
        activity.sessionId = getSessionId();
        
        sessionMonitor.suspiciousActivity.push(activity);

        createAuditLog(AUDIT_TYPES.SUSPICIOUS_ACTIVITY, activity);

        // Keep only last 50 suspicious activities
        if (sessionMonitor.suspiciousActivity.length > 50) {
            sessionMonitor.suspiciousActivity.shift();
        }
    }

    /**
     * Update last activity timestamp
     */
    function updateActivity() {
        sessionMonitor.lastActivity = Date.now();
    }

    /**
     * Check session timeout
     */
    function checkSessionTimeout() {
        const api = window.App?.api || window.APIModule;
        
        if (!api || !api.session || !api.session.loggedIn) {
            return false;
        }

        const timeSinceActivity = Date.now() - sessionMonitor.lastActivity;
        
        if (timeSinceActivity > SECURITY_CONFIG.sessionTimeout) {
            createAuditLog(AUDIT_TYPES.SESSION_TIMEOUT, {
                inactiveTime: timeSinceActivity,
                timeout: SECURITY_CONFIG.sessionTimeout
            });

            // Logout user
            if (api.passengerLogout) {
                api.passengerLogout();
            }

            // Show timeout message
            if (window.App?.notifications?.show) {
                window.App.notifications.show(
                    'Session expired due to inactivity. Please log in again.',
                    'warning'
                );
            }

            return true;
        }

        return false;
    }

    /**
     * Get audit logs
     */
    function getAuditLogs(filters = {}) {
        let logs = [...auditLog];

        // Filter by type
        if (filters.type) {
            logs = logs.filter(log => log.type === filters.type);
        }

        // Filter by user
        if (filters.userId) {
            logs = logs.filter(log => log.userId === filters.userId);
        }

        // Filter by role
        if (filters.userRole) {
            logs = logs.filter(log => log.userRole === filters.userRole);
        }

        // Filter by date range
        if (filters.startDate) {
            logs = logs.filter(log => new Date(log.timestamp) >= new Date(filters.startDate));
        }

        if (filters.endDate) {
            logs = logs.filter(log => new Date(log.timestamp) <= new Date(filters.endDate));
        }

        // Limit results
        if (filters.limit) {
            logs = logs.slice(0, filters.limit);
        }

        return logs;
    }

    /**
     * Get security statistics
     */
    function getSecurityStats() {
        const now = Date.now();
        const last24Hours = now - (24 * 60 * 60 * 1000);

        return {
            totalAuditLogs: auditLog.length,
            recentLogins: auditLog.filter(log => 
                log.type === AUDIT_TYPES.LOGIN_SUCCESS && 
                new Date(log.timestamp).getTime() > last24Hours
            ).length,
            failedLogins: auditLog.filter(log => 
                log.type === AUDIT_TYPES.LOGIN_FAILURE && 
                new Date(log.timestamp).getTime() > last24Hours
            ).length,
            permissionDenials: auditLog.filter(log => 
                log.type === AUDIT_TYPES.PERMISSION_DENIED && 
                new Date(log.timestamp).getTime() > last24Hours
            ).length,
            suspiciousActivities: sessionMonitor.suspiciousActivity.length,
            lockedAccounts: Object.keys(sessionMonitor.loginAttempts).filter(email =>
                isAccountLocked(email)
            ).length,
            lastActivity: new Date(sessionMonitor.lastActivity).toISOString(),
            sessionTimeout: SECURITY_CONFIG.sessionTimeout,
            timeUntilTimeout: Math.max(0, SECURITY_CONFIG.sessionTimeout - (now - sessionMonitor.lastActivity))
        };
    }

    /**
     * Initialize security module
     */
    function init() {
        console.log('[Security] Initializing security & audit module...');

        // Track user activity
        ['click', 'keypress', 'scroll', 'mousemove'].forEach(event => {
            document.addEventListener(event, updateActivity, { passive: true });
        });

        // Check session timeout periodically
        setInterval(checkSessionTimeout, 60000); // Every minute

        // Initial activity timestamp
        updateActivity();

        console.log('[Security] Security module initialized');
    }

    /**
     * Export security module
     */
    const SecurityModule = {
        // Audit logging
        createAuditLog,
        getAuditLogs,
        AUDIT_TYPES,

        // Authorization
        authorize,
        authorizeRole,

        // Login security
        trackLoginAttempt,
        isAccountLocked,

        // Session monitoring
        updateActivity,
        checkSessionTimeout,
        flagSuspiciousActivity,

        // Statistics
        getSecurityStats,

        // Configuration
        SECURITY_CONFIG,

        // Initialization
        init
    };

    // Export to global namespace
    window.SecurityModule = SecurityModule;
    App.security = SecurityModule;

    // Auto-initialize
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();
