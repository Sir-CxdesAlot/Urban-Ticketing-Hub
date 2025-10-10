/**
 * Notification Service Module
 * Handles notifications, alerts, preferences, and real-time updates
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});
    const CONFIG = {
        baseUrl: 'http://localhost:8085',
        endpoints: {
            list: '/api/v1/notification/list',
            passenger: '/api/v1/notification/passenger',
            unread: '/api/v1/notification/unread',
            markRead: '/api/v1/notification/mark-read',
            preferences: '/api/v1/notification/preferences',
            send: '/api/v1/notification/send',
            statistics: '/api/v1/notification/statistics'
        }
    };

    // Helper Functions
    function showLoading(containerId) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = '<div class="loading">Loading...</div>';
        }
    }

    function showError(containerId, message) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `<div class="error-message">❌ ${message}</div>`;
        }
    }

    function showSuccess(containerId, message) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `<div class="success-message">✅ ${message}</div>`;
        }
    }

    function showEmpty(containerId, message) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `<div class="info-message">ℹ️ ${message}</div>`;
        }
    }

    function formatDate(dateString) {
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('en-NA', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    function getTimeAgo(dateString) {
        const date = new Date(dateString);
        const now = new Date();
        const seconds = Math.floor((now - date) / 1000);

        if (seconds < 60) return 'Just now';
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes} minute${minutes !== 1 ? 's' : ''} ago`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} hour${hours !== 1 ? 's' : ''} ago`;
        const days = Math.floor(hours / 24);
        if (days < 7) return `${days} day${days !== 1 ? 's' : ''} ago`;
        const weeks = Math.floor(days / 7);
        if (weeks < 4) return `${weeks} week${weeks !== 1 ? 's' : ''} ago`;
        const months = Math.floor(days / 30);
        return `${months} month${months !== 1 ? 's' : ''} ago`;
    }

    function getNotificationIcon(type) {
        const icons = {
            'INFO': 'ℹ️',
            'SUCCESS': '✅',
            'WARNING': '⚠️',
            'ERROR': '❌',
            'ALERT': '🔔',
            'TRIP': '🚌',
            'TICKET': '🎫',
            'PAYMENT': '💳',
            'SYSTEM': '⚙️',
            'PROMOTION': '🎉',
            'REMINDER': '⏰'
        };
        return icons[type] || '📢';
    }

    function getNotificationBadgeClass(type) {
        const typeMap = {
            'INFO': 'badge-info',
            'SUCCESS': 'badge-success',
            'WARNING': 'badge-warning',
            'ERROR': 'badge-danger',
            'ALERT': 'badge-warning',
            'TRIP': 'badge-info',
            'TICKET': 'badge-success',
            'PAYMENT': 'badge-info',
            'SYSTEM': 'badge-info',
            'PROMOTION': 'badge-success',
            'REMINDER': 'badge-warning'
        };
        return typeMap[type] || 'badge-info';
    }

    function getPriorityBadge(priority) {
        const badges = {
            'HIGH': '<span class="badge badge-danger">High Priority</span>',
            'MEDIUM': '<span class="badge badge-warning">Medium</span>',
            'LOW': '<span class="badge badge-info">Low</span>'
        };
        return badges[priority] || '';
    }

    // API Request Helper
    async function apiRequest(endpoint, method = 'GET', data = null) {
        const session = window.APIModule?.session || App.api?.session;
        
        const options = {
            method,
            headers: {
                'Content-Type': 'application/json'
            }
        };

        if (session?.token) {
            options.headers['Authorization'] = `Bearer ${session.token}`;
        }

        if (data && method !== 'GET') {
            options.body = JSON.stringify(data);
        }

        const url = `${CONFIG.baseUrl}${endpoint}`;
        console.log(`Notification API: ${method} ${url}`, data || '');

        const response = await fetch(url, options);
        const result = await response.json();

        if (!response.ok) {
            throw new Error(result.message || `Request failed: ${response.status}`);
        }

        return result;
    }

    // Check if user is logged in
    function checkAuthentication() {
        const session = window.APIModule?.session || App.api?.session;
        return session?.loggedIn || false;
    }

    // Test Functions

    /**
     * Test 1: Get All Notifications
     * Fetch all notifications for the user
     */
    async function testGetNotifications() {
        const containerId = 'notificationsResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view notifications');
            return;
        }

        try {
            const limit = parseInt(document.getElementById('notificationsLimit')?.value || '10');
            const response = await apiRequest(`${CONFIG.endpoints.list}?limit=${limit}`, 'GET');
            
            const notifications = response.notifications || response.data || response || [];

            if (!notifications.length) {
                showEmpty(containerId, 'No notifications found');
                return;
            }

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    ${notifications.map(notif => `
                        <div class="result-item ${notif.read === false ? 'unread-notification' : ''}">
                            <div class="result-header">
                                <strong>${getNotificationIcon(notif.type)} ${notif.title || 'Notification'}</strong>
                                <div>
                                    <span class="badge ${getNotificationBadgeClass(notif.type)}">${notif.type}</span>
                                    ${notif.read === false ? '<span class="badge badge-warning">Unread</span>' : ''}
                                    ${getPriorityBadge(notif.priority)}
                                </div>
                            </div>
                            <div class="result-details">
                                <div style="margin-bottom: 8px;">${notif.message || notif.content || 'No message'}</div>
                                ${notif.timestamp || notif.createdAt ? `<div class="subtle"><strong>Time:</strong> ${getTimeAgo(notif.timestamp || notif.createdAt)}</div>` : ''}
                                ${notif.id ? `<div class="subtle"><strong>ID:</strong> ${notif.id}</div>` : ''}
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;

            console.log('Notifications:', notifications);
        } catch (error) {
            console.error('Get notifications error:', error);
            showError(containerId, error.message || 'Failed to load notifications');
        }
    }

    /**
     * Test 2: Get Unread Notifications
     * Fetch only unread notifications
     */
    async function testGetUnreadNotifications() {
        const containerId = 'unreadResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view unread notifications');
            return;
        }

        try {
            const response = await apiRequest(CONFIG.endpoints.unread, 'GET');
            const notifications = response.notifications || response.data || response || [];

            if (!notifications.length) {
                showEmpty(containerId, 'No unread notifications');
                return;
            }

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    <div class="info-message" style="margin-bottom: 16px;">
                        📬 You have ${notifications.length} unread notification${notifications.length !== 1 ? 's' : ''}
                    </div>
                    ${notifications.map(notif => `
                        <div class="result-item unread-notification">
                            <div class="result-header">
                                <strong>${getNotificationIcon(notif.type)} ${notif.title || 'Notification'}</strong>
                                <span class="badge ${getNotificationBadgeClass(notif.type)}">${notif.type}</span>
                            </div>
                            <div class="result-details">
                                <div style="margin-bottom: 8px;">${notif.message || notif.content || 'No message'}</div>
                                ${notif.timestamp || notif.createdAt ? `<div class="subtle">${getTimeAgo(notif.timestamp || notif.createdAt)}</div>` : ''}
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;

            console.log('Unread notifications:', notifications);
        } catch (error) {
            console.error('Get unread notifications error:', error);
            showError(containerId, error.message || 'Failed to load unread notifications');
        }
    }

    /**
     * Test 3: Mark as Read
     * Mark a notification as read
     */
    async function testMarkAsRead() {
        const containerId = 'markReadResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to mark notifications as read');
            return;
        }

        try {
            const notificationId = document.getElementById('markReadId')?.value?.trim();

            if (!notificationId) {
                showError(containerId, 'Please enter a notification ID');
                return;
            }

            const response = await apiRequest(CONFIG.endpoints.markRead, 'POST', {
                notificationId
            });

            showSuccess(containerId, 'Notification marked as read successfully!');
            
            // Add details if available
            if (response.notification || response.data) {
                const notif = response.notification || response.data;
                const container = document.getElementById(containerId);
                container.innerHTML += `
                    <div class="results" style="margin-top: 12px;">
                        <div class="result-item">
                            <div class="result-header">
                                <strong>${getNotificationIcon(notif.type)} ${notif.title || 'Notification'}</strong>
                                <span class="badge badge-success">Read</span>
                            </div>
                            <div class="result-details">
                                <div><strong>ID:</strong> ${notificationId}</div>
                                ${notif.message ? `<div><strong>Message:</strong> ${notif.message}</div>` : ''}
                            </div>
                        </div>
                    </div>
                `;
            }

            console.log('Marked as read:', response);
        } catch (error) {
            console.error('Mark as read error:', error);
            showError(containerId, error.message || 'Failed to mark notification as read');
        }
    }

    /**
     * Test 4: Notification Preferences
     * Get or update notification preferences
     */
    async function testNotificationPreferences() {
        const containerId = 'preferencesResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view notification preferences');
            return;
        }

        try {
            const response = await apiRequest(CONFIG.endpoints.preferences, 'GET');
            const prefs = response.preferences || response.data || response;

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    <div class="result-item">
                        <div class="result-header">
                            <strong>⚙️ Notification Preferences</strong>
                        </div>
                        <div class="result-details">
                            <div><strong>Email Notifications:</strong> ${prefs.email !== false ? '✅ Enabled' : '❌ Disabled'}</div>
                            <div><strong>SMS Notifications:</strong> ${prefs.sms !== false ? '✅ Enabled' : '❌ Disabled'}</div>
                            <div><strong>Push Notifications:</strong> ${prefs.push !== false ? '✅ Enabled' : '❌ Disabled'}</div>
                            <div><strong>Trip Updates:</strong> ${prefs.tripUpdates !== false ? '✅ Enabled' : '❌ Disabled'}</div>
                            <div><strong>Payment Alerts:</strong> ${prefs.paymentAlerts !== false ? '✅ Enabled' : '❌ Disabled'}</div>
                            <div><strong>Promotional Offers:</strong> ${prefs.promotions !== false ? '✅ Enabled' : '❌ Disabled'}</div>
                        </div>
                    </div>
                </div>
            `;

            console.log('Notification preferences:', prefs);
        } catch (error) {
            console.error('Get preferences error:', error);
            showError(containerId, error.message || 'Failed to load notification preferences');
        }
    }

    /**
     * Test 5: Filter Notifications
     * Filter notifications by type
     */
    async function testFilterNotifications() {
        const containerId = 'filterResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to filter notifications');
            return;
        }

        try {
            const type = document.getElementById('filterType')?.value;
            const unreadOnly = document.getElementById('filterUnreadOnly')?.checked;

            // Get all notifications first
            const response = await apiRequest(CONFIG.endpoints.list, 'GET');
            let notifications = response.notifications || response.data || response || [];

            // Apply filters
            if (type) {
                notifications = notifications.filter(n => n.type === type);
            }

            if (unreadOnly) {
                notifications = notifications.filter(n => n.read === false);
            }

            if (!notifications.length) {
                showEmpty(containerId, 'No notifications match your filter criteria');
                return;
            }

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    <div class="info-message" style="margin-bottom: 16px;">
                        Found ${notifications.length} notification${notifications.length !== 1 ? 's' : ''}
                        ${type ? ` of type ${type}` : ''}
                        ${unreadOnly ? ' (unread only)' : ''}
                    </div>
                    ${notifications.map(notif => `
                        <div class="result-item ${notif.read === false ? 'unread-notification' : ''}">
                            <div class="result-header">
                                <strong>${getNotificationIcon(notif.type)} ${notif.title || 'Notification'}</strong>
                                <div>
                                    <span class="badge ${getNotificationBadgeClass(notif.type)}">${notif.type}</span>
                                    ${notif.read === false ? '<span class="badge badge-warning">Unread</span>' : ''}
                                </div>
                            </div>
                            <div class="result-details">
                                <div style="margin-bottom: 8px;">${notif.message || notif.content || 'No message'}</div>
                                ${notif.timestamp || notif.createdAt ? `<div class="subtle">${getTimeAgo(notif.timestamp || notif.createdAt)}</div>` : ''}
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;

            console.log('Filtered notifications:', notifications);
        } catch (error) {
            console.error('Filter notifications error:', error);
            showError(containerId, error.message || 'Failed to filter notifications');
        }
    }

    /**
     * Test 6: Notification Statistics
     * Get notification statistics and analytics
     */
    async function testNotificationStatistics() {
        const containerId = 'notificationStatsResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view notification statistics');
            return;
        }

        try {
            // Try to get statistics from API
            let stats;
            try {
                const response = await apiRequest(CONFIG.endpoints.statistics, 'GET');
                stats = response.statistics || response.data || response;
            } catch (error) {
                // If endpoint doesn't exist, calculate from notifications list
                const response = await apiRequest(CONFIG.endpoints.list, 'GET');
                const notifications = response.notifications || response.data || response || [];
                
                stats = {
                    total: notifications.length,
                    unread: notifications.filter(n => n.read === false).length,
                    read: notifications.filter(n => n.read !== false).length,
                    byType: {}
                };

                // Count by type
                notifications.forEach(n => {
                    const type = n.type || 'UNKNOWN';
                    stats.byType[type] = (stats.byType[type] || 0) + 1;
                });
            }

            const totalNotifications = stats.total || 0;
            const unreadCount = stats.unread || 0;
            const readCount = stats.read || 0;
            const mostCommonType = stats.mostCommonType || Object.keys(stats.byType || {}).sort((a, b) => 
                (stats.byType[b] || 0) - (stats.byType[a] || 0)
            )[0] || 'N/A';

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-value">${totalNotifications}</div>
                        <div class="stat-label">Total Notifications</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${unreadCount}</div>
                        <div class="stat-label">Unread</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${readCount}</div>
                        <div class="stat-label">Read</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${unreadCount > 0 ? ((unreadCount / totalNotifications) * 100).toFixed(0) : 0}%</div>
                        <div class="stat-label">Unread Percentage</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${Object.keys(stats.byType || {}).length || 0}</div>
                        <div class="stat-label">Notification Types</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${getNotificationIcon(mostCommonType)} ${mostCommonType}</div>
                        <div class="stat-label">Most Common Type</div>
                    </div>
                </div>
            `;

            console.log('Notification statistics:', stats);
        } catch (error) {
            console.error('Notification statistics error:', error);
            showError(containerId, error.message || 'Failed to load notification statistics');
        }
    }

    /**
     * Initialize Notification View
     * Set up the notification view with default values and clear containers
     */
    async function initNotificationView() {
        console.log('Initializing Notification Service view...');
        
        // Check authentication
        if (!checkAuthentication()) {
            const containers = [
                'notificationsResult', 'unreadResult', 'markReadResult',
                'preferencesResult', 'filterResult', 'notificationStatsResult'
            ];
            containers.forEach(id => {
                const container = document.getElementById(id);
                if (container) {
                    container.innerHTML = '<div class="info-message">ℹ️ Please login to access notifications</div>';
                }
            });
            return;
        }

        // Clear all result containers
        const containers = [
            'notificationsResult', 'unreadResult', 'markReadResult',
            'preferencesResult', 'filterResult', 'notificationStatsResult'
        ];
        
        containers.forEach(id => {
            const container = document.getElementById(id);
            if (container) container.innerHTML = '';
        });

        // Set default values for inputs
        const notificationsLimit = document.getElementById('notificationsLimit');
        if (notificationsLimit && !notificationsLimit.value) {
            notificationsLimit.value = '10';
        }

        console.log('Notification Service view initialized');
    }

    // Export functions
    App.notification = {
        testGetNotifications,
        testGetUnreadNotifications,
        testMarkAsRead,
        testNotificationPreferences,
        testFilterNotifications,
        testNotificationStatistics,
        initNotificationView
    };

    // Export to window for inline onclick handlers
    window.testGetNotifications = testGetNotifications;
    window.testGetUnreadNotifications = testGetUnreadNotifications;
    window.testMarkAsRead = testMarkAsRead;
    window.testNotificationPreferences = testNotificationPreferences;
    window.testFilterNotifications = testFilterNotifications;
    window.testNotificationStatistics = testNotificationStatistics;

    console.log('Notification module loaded');
})();
