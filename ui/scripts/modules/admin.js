/**
 * Admin Service Module
 * Handles administrative functions including system monitoring, user management, and analytics
 * Port: 8086
 */

(function() {
    'use strict';

    // Admin Service Module
    window.AdminModule = {
        /**
         * Test 1: Get System Statistics
         * Retrieves comprehensive system-wide statistics and metrics
         */
        testSystemStatistics: async function() {
            const resultDiv = document.getElementById('systemStatsResult');
            if (!resultDiv) return;

            resultDiv.innerHTML = '<div class="loading">Loading system statistics...</div>';

            try {
                const response = await window.APIModule.fetchAdminSystemStats();
                
                if (response && response.success && response.data) {
                    const stats = response.data;
                    
                    resultDiv.innerHTML = `
                        <div class="result-success">
                            <div class="result-header">
                                <strong>✅ System Statistics Retrieved</strong>
                            </div>
                            <div class="stats-grid">
                                <div class="stat-card">
                                    <div class="stat-icon">👥</div>
                                    <div class="stat-label">Total Users</div>
                                    <div class="stat-value">${stats.totalUsers || 0}</div>
                                    <div class="stat-detail">Active: ${stats.activeUsers || 0}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">🚌</div>
                                    <div class="stat-label">Total Routes</div>
                                    <div class="stat-value">${stats.totalRoutes || 0}</div>
                                    <div class="stat-detail">Active: ${stats.activeRoutes || 0}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">🎫</div>
                                    <div class="stat-label">Total Tickets</div>
                                    <div class="stat-value">${stats.totalTickets || 0}</div>
                                    <div class="stat-detail">Today: ${stats.ticketsToday || 0}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">💰</div>
                                    <div class="stat-label">Total Revenue</div>
                                    <div class="stat-value">NAD ${this.formatCurrency(stats.totalRevenue || 0)}</div>
                                    <div class="stat-detail">This month: NAD ${this.formatCurrency(stats.revenueThisMonth || 0)}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">🚍</div>
                                    <div class="stat-label">Active Trips</div>
                                    <div class="stat-value">${stats.activeTrips || 0}</div>
                                    <div class="stat-detail">Completed: ${stats.completedTrips || 0}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">📊</div>
                                    <div class="stat-label">System Health</div>
                                    <div class="stat-value">${this.getHealthBadge(stats.systemHealth)}</div>
                                    <div class="stat-detail">Uptime: ${stats.uptime || '99.9%'}</div>
                                </div>
                            </div>
                        </div>
                    `;
                    
                    // Trigger masonry layout
                    this.applyMasonryLayout(resultDiv);
                } else {
                    resultDiv.innerHTML = `
                        <div class="result-error">
                            <strong>❌ Failed to retrieve statistics</strong>
                            <p>${response?.message || 'Unknown error occurred'}</p>
                        </div>
                    `;
                }
            } catch (error) {
                console.error('System statistics error:', error);
                resultDiv.innerHTML = `
                    <div class="result-error">
                        <strong>❌ Error</strong>
                        <p>${error.message || 'Failed to connect to admin service'}</p>
                    </div>
                `;
            }
        },

        /**
         * Test 2: Get User Management Overview
         * Retrieves user list and management information
         */
        testUserManagement: async function() {
            const resultDiv = document.getElementById('userManagementResult');
            if (!resultDiv) return;

            const limit = parseInt(document.getElementById('userLimit')?.value) || 20;

            resultDiv.innerHTML = '<div class="loading">Loading users...</div>';

            try {
                const response = await window.APIModule.fetchAdminUsers({ limit });
                
                if (response && response.success && response.data) {
                    const users = Array.isArray(response.data) ? response.data : [];
                    
                    if (users.length === 0) {
                        resultDiv.innerHTML = `
                            <div class="result-info">
                                <strong>ℹ️ No Users Found</strong>
                                <p>No admin users are currently registered in the system.</p>
                            </div>
                        `;
                        return;
                    }
                    
                    let usersHtml = users.map(user => {
                        // Handle the admin user object structure
                        const username = user.username || 'Unknown';
                        const email = user.email || 'N/A';
                        const role = user.role || 'UNKNOWN';
                        const userId = user.id || user._id || 'N/A';
                        const createdAt = user.createdAt || new Date();
                        const lastLogin = user.lastLogin || null;
                        
                        return `
                        <div class="user-card">
                            <div class="user-avatar">${username.charAt(0).toUpperCase()}</div>
                            <div class="user-info">
                                <div class="user-name">${username}</div>
                                <div class="user-email">${email}</div>
                                <div class="user-meta">
                                    <span class="badge badge-${this.getRoleBadgeClass(role)}">${role}</span>
                                    <span class="status-badge ${lastLogin ? 'active' : 'unknown'}">${lastLogin ? 'Active' : 'Never Logged In'}</span>
                                </div>
                            </div>
                        </div>
                    `}).join('');

                    resultDiv.innerHTML = `
                        <div class="result-success">
                            <div class="result-header">
                                <strong>✅ Retrieved ${users.length} Admin Users</strong>
                            </div>
                            ${usersHtml}
                            <div class="result-footer">
                                <small>Total admin users in system: ${users.length}</small>
                            </div>
                        </div>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <div class="result-error">
                            <strong>❌ Failed to retrieve users</strong>
                            <p>${response?.message || 'Unknown error occurred'}</p>
                            ${response?.data ? `<pre style="margin-top:8px;font-size:0.75rem;overflow:auto;">${JSON.stringify(response.data, null, 2)}</pre>` : ''}
                        </div>
                    `;
                }
            } catch (error) {
                console.error('User management error:', error);
                resultDiv.innerHTML = `
                    <div class="result-error">
                        <strong>❌ Error</strong>
                        <p>${error.message || 'Failed to connect to admin service'}</p>
                    </div>
                `;
            }
        },

        /**
         * Test 3: Get Route Management Overview
         * Retrieves route management information and statistics
         */
        testRouteManagement: async function() {
            const resultDiv = document.getElementById('routeManagementResult');
            if (!resultDiv) return;

            resultDiv.innerHTML = '<div class="loading">Loading route management data...</div>';

            try {
                const response = await window.APIModule.fetchAdminRoutes();
                
                if (response && response.success && response.data) {
                    const routes = response.data;
                    
                    let routesHtml = routes.map(route => `
                        <div class="result-item">
                            <div class="result-header">
                                <strong>🚌 ${route.origin} → ${route.destination}</strong>
                                <span class="badge ${this.getStatusBadgeClass(route.status)}">${route.status}</span>
                            </div>
                            <div class="result-details">
                                <div><strong>Route ID:</strong> ${route.id}</div>
                                <div><strong>Number:</strong> ${route.routeNumber}</div>
                                <div><strong>Type:</strong> ${this.getTransportIcon(route.transportType)} ${route.transportType}</div>
                                <div><strong>Distance:</strong> ${route.distance} km</div>
                                <div><strong>Duration:</strong> ${route.estimatedDuration} min</div>
                                <div><strong>Base Fare:</strong> NAD ${this.formatCurrency(route.baseFare)}</div>
                                <div><strong>Stops:</strong> ${route.stops?.length || 0}</div>
                                <div><strong>Daily Trips:</strong> ${route.dailyTrips || 0}</div>
                                <div><strong>Total Passengers:</strong> ${route.totalPassengers || 0}</div>
                                <div><strong>Revenue:</strong> NAD ${this.formatCurrency(route.totalRevenue || 0)}</div>
                            </div>
                        </div>
                    `).join('');

                    resultDiv.innerHTML = `
                        <div class="result-success">
                            <div class="result-header">
                                <strong>✅ Retrieved ${routes.length} Routes</strong>
                            </div>
                            ${routesHtml}
                            <div class="result-footer">
                                <small>Total routes in system: ${response.total || routes.length}</small>
                            </div>
                        </div>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <div class="result-error">
                            <strong>❌ Failed to retrieve routes</strong>
                            <p>${response?.message || 'Unknown error occurred'}</p>
                        </div>
                    `;
                }
            } catch (error) {
                console.error('Route management error:', error);
                resultDiv.innerHTML = `
                    <div class="result-error">
                        <strong>❌ Error</strong>
                        <p>${error.message || 'Failed to connect to admin service'}</p>
                    </div>
                `;
            }
        },

        /**
         * Test 4: Get Service Health Monitoring
         * Retrieves health status of all microservices
         */
        testServiceHealth: async function() {
            const resultDiv = document.getElementById('serviceHealthResult');
            if (!resultDiv) return;

            resultDiv.innerHTML = '<div class="loading">Checking service health...</div>';

            try {
                const response = await window.APIModule.fetchAdminServiceHealth();
                
                if (response && response.success && response.data) {
                    const services = response.data;
                    
                    let servicesHtml = Object.entries(services).map(([name, health]) => `
                        <div class="result-item">
                            <div class="result-header">
                                <strong>${this.getServiceIcon(name)} ${this.capitalize(name)} Service</strong>
                                ${this.getHealthStatusBadge(health.status)}
                            </div>
                            <div class="result-details">
                                <div><strong>Port:</strong> ${health.port || 'N/A'}</div>
                                <div><strong>Status:</strong> ${health.status}</div>
                                <div><strong>Response Time:</strong> ${health.responseTime || 0}ms</div>
                                <div><strong>Uptime:</strong> ${health.uptime || 'N/A'}</div>
                                <div><strong>Memory:</strong> ${health.memory || 'N/A'}</div>
                                <div><strong>CPU:</strong> ${health.cpu || 'N/A'}</div>
                                <div><strong>Requests/min:</strong> ${health.requestsPerMinute || 0}</div>
                                <div><strong>Error Rate:</strong> ${health.errorRate || '0%'}</div>
                                <div><strong>Last Check:</strong> ${this.formatDate(health.lastCheck || new Date())}</div>
                            </div>
                        </div>
                    `).join('');

                    resultDiv.innerHTML = `
                        <div class="result-success">
                            <div class="result-header">
                                <strong>✅ Service Health Status</strong>
                            </div>
                            ${servicesHtml}
                            <div class="result-footer">
                                <small>All services monitored • Last updated: ${new Date().toLocaleString()}</small>
                            </div>
                        </div>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <div class="result-error">
                            <strong>❌ Failed to retrieve service health</strong>
                            <p>${response?.message || 'Unknown error occurred'}</p>
                        </div>
                    `;
                }
            } catch (error) {
                console.error('Service health error:', error);
                resultDiv.innerHTML = `
                    <div class="result-error">
                        <strong>❌ Error</strong>
                        <p>${error.message || 'Failed to connect to admin service'}</p>
                    </div>
                `;
            }
        },

        /**
         * Test 5: Get Revenue Analytics
         * Retrieves detailed revenue and financial analytics
         */
        testRevenueAnalytics: async function() {
            const resultDiv = document.getElementById('revenueAnalyticsResult');
            if (!resultDiv) return;

            const period = document.getElementById('revenuePeriod')?.value || 'month';

            resultDiv.innerHTML = '<div class="loading">Loading revenue analytics...</div>';

            try {
                const response = await window.APIModule.fetchAdminRevenueAnalytics({ period });
                
                if (response && response.success && response.data) {
                    const analytics = response.data;
                    
                    resultDiv.innerHTML = `
                        <div class="result-success">
                            <div class="result-header">
                                <strong>✅ Revenue Analytics (${this.capitalize(period)})</strong>
                            </div>
                            <div class="stats-grid">
                                <div class="stat-card">
                                    <div class="stat-icon">💰</div>
                                    <div class="stat-label">Total Revenue</div>
                                    <div class="stat-value">NAD ${this.formatCurrency(analytics.totalRevenue || 0)}</div>
                                    <div class="stat-detail">
                                        ${analytics.revenueChange >= 0 ? '📈' : '📉'} 
                                        ${Math.abs(analytics.revenueChange || 0)}% vs last ${period}
                                    </div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">🎫</div>
                                    <div class="stat-label">Tickets Sold</div>
                                    <div class="stat-value">${analytics.ticketsSold || 0}</div>
                                    <div class="stat-detail">Avg: NAD ${this.formatCurrency(analytics.averageTicketPrice || 0)}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">💳</div>
                                    <div class="stat-label">Transactions</div>
                                    <div class="stat-value">${analytics.totalTransactions || 0}</div>
                                    <div class="stat-detail">Success: ${analytics.successRate || 0}%</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">💸</div>
                                    <div class="stat-label">Refunds</div>
                                    <div class="stat-value">NAD ${this.formatCurrency(analytics.totalRefunds || 0)}</div>
                                    <div class="stat-detail">Count: ${analytics.refundCount || 0}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">📊</div>
                                    <div class="stat-label">Top Route</div>
                                    <div class="stat-value">${analytics.topRoute || 'N/A'}</div>
                                    <div class="stat-detail">Revenue: NAD ${this.formatCurrency(analytics.topRouteRevenue || 0)}</div>
                                </div>
                                <div class="stat-card">
                                    <div class="stat-icon">🏆</div>
                                    <div class="stat-label">Top Payment Method</div>
                                    <div class="stat-value">${analytics.topPaymentMethod || 'N/A'}</div>
                                    <div class="stat-detail">${analytics.topPaymentPercentage || 0}% of total</div>
                                </div>
                            </div>
                            <div class="result-details" style="margin-top: 16px;">
                                <h4>Revenue Breakdown by Payment Method:</h4>
                                ${this.renderRevenueBreakdown(analytics.paymentMethodBreakdown)}
                            </div>
                            <div class="result-details" style="margin-top: 16px;">
                                <h4>Revenue by Transport Type:</h4>
                                ${this.renderRevenueBreakdown(analytics.transportTypeBreakdown)}
                            </div>
                        </div>
                    `;
                    
                    // Trigger masonry layout
                    this.applyMasonryLayout(resultDiv);
                } else {
                    resultDiv.innerHTML = `
                        <div class="result-error">
                            <strong>❌ Failed to retrieve revenue analytics</strong>
                            <p>${response?.message || 'Unknown error occurred'}</p>
                        </div>
                    `;
                }
            } catch (error) {
                console.error('Revenue analytics error:', error);
                resultDiv.innerHTML = `
                    <div class="result-error">
                        <strong>❌ Error</strong>
                        <p>${error.message || 'Failed to connect to admin service'}</p>
                    </div>
                `;
            }
        },

        /**
         * Test 6: Get Activity Logs
         * Retrieves recent system activity and audit logs
         */
        testActivityLogs: async function() {
            const resultDiv = document.getElementById('activityLogsResult');
            if (!resultDiv) return;

            const limit = parseInt(document.getElementById('logsLimit')?.value) || 50;
            const logType = document.getElementById('logType')?.value || 'all';

            resultDiv.innerHTML = '<div class="loading">Loading activity logs...</div>';

            try {
                const response = await window.APIModule.fetchAdminActivityLogs({ limit, type: logType });
                
                if (response && response.success && response.data) {
                    const logs = response.data;
                    
                    let logsHtml = logs.map(log => `
                        <div class="result-item">
                            <div class="result-header">
                                <strong>${this.getActivityIcon(log.action)} ${log.action}</strong>
                                <span class="badge ${this.getActivityBadgeClass(log.level)}">${log.level}</span>
                            </div>
                            <div class="result-details">
                                <div><strong>Timestamp:</strong> ${this.formatDate(log.timestamp)}</div>
                                <div><strong>User:</strong> ${log.userId || 'System'} (${log.userType || 'N/A'})</div>
                                <div><strong>Action:</strong> ${log.action}</div>
                                <div><strong>Resource:</strong> ${log.resource || 'N/A'}</div>
                                <div><strong>Details:</strong> ${log.details || 'No additional details'}</div>
                                <div><strong>IP Address:</strong> ${log.ipAddress || 'N/A'}</div>
                                <div><strong>Status:</strong> ${this.getLogStatusBadge(log.status)}</div>
                            </div>
                        </div>
                    `).join('');

                    resultDiv.innerHTML = `
                        <div class="result-success">
                            <div class="result-header">
                                <strong>✅ Retrieved ${logs.length} Activity Logs</strong>
                            </div>
                            ${logsHtml}
                            <div class="result-footer">
                                <small>Showing ${logs.length} of ${response.total || logs.length} logs • Filter: ${logType}</small>
                            </div>
                        </div>
                    `;
                } else {
                    resultDiv.innerHTML = `
                        <div class="result-error">
                            <strong>❌ Failed to retrieve activity logs</strong>
                            <p>${response?.message || 'Unknown error occurred'}</p>
                        </div>
                    `;
                }
            } catch (error) {
                console.error('Activity logs error:', error);
                resultDiv.innerHTML = `
                    <div class="result-error">
                        <strong>❌ Error</strong>
                        <p>${error.message || 'Failed to connect to admin service'}</p>
                    </div>
                `;
            }
        },

        // Helper Functions

        /**
         * Format currency value
         */
        formatCurrency: function(amount) {
            return parseFloat(amount || 0).toLocaleString('en-NA', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            });
        },

        /**
         * Format date to readable string
         */
        formatDate: function(dateString) {
            if (!dateString) return 'N/A';
            const date = new Date(dateString);
            return date.toLocaleString('en-NA', {
                year: 'numeric',
                month: 'short',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            });
        },

        /**
         * Capitalize first letter
         */
        capitalize: function(str) {
            if (!str) return '';
            return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
        },

        /**
         * Get health badge HTML
         */
        getHealthBadge: function(health) {
            const badges = {
                excellent: '<span class="badge badge-success">EXCELLENT</span>',
                good: '<span class="badge badge-success">GOOD</span>',
                fair: '<span class="badge badge-warning">FAIR</span>',
                poor: '<span class="badge badge-error">POOR</span>'
            };
            return badges[health?.toLowerCase()] || badges.good;
        },

        /**
         * Get user icon
         */
        getUserIcon: function(userType) {
            const icons = {
                passenger: '👤',
                admin: '👨‍💼',
                driver: '🚗',
                operator: '🎫'
            };
            return icons[userType?.toLowerCase()] || '👤';
        },

        /**
         * Get user type badge class
         */
        getUserTypeBadgeClass: function(userType) {
            const classes = {
                passenger: 'badge-info',
                admin: 'badge-error',
                driver: 'badge-warning',
                operator: 'badge-success'
            };
            return classes[userType?.toLowerCase()] || 'badge-info';
        },

        /**
         * Get status badge HTML
         */
        getStatusBadge: function(status) {
            const badges = {
                active: '<span class="badge badge-success">ACTIVE</span>',
                inactive: '<span class="badge badge-warning">INACTIVE</span>',
                suspended: '<span class="badge badge-error">SUSPENDED</span>',
                pending: '<span class="badge badge-info">PENDING</span>'
            };
            return badges[status?.toLowerCase()] || badges.active;
        },

        /**
         * Get status badge class
         */
        getStatusBadgeClass: function(status) {
            const classes = {
                active: 'badge-success',
                inactive: 'badge-warning',
                suspended: 'badge-error',
                pending: 'badge-info'
            };
            return classes[status?.toLowerCase()] || 'badge-success';
        },

        /**
         * Get transport icon
         */
        getTransportIcon: function(type) {
            const icons = {
                bus: '🚌',
                train: '🚆',
                taxi: '🚕',
                shuttle: '🚐'
            };
            return icons[type?.toLowerCase()] || '🚌';
        },

        /**
         * Get service icon
         */
        getServiceIcon: function(name) {
            const icons = {
                passenger: '👥',
                transport: '🚌',
                ticketing: '🎫',
                payment: '💳',
                notification: '🔔',
                admin: '⚙️'
            };
            return icons[name?.toLowerCase()] || '⚙️';
        },

        /**
         * Get health status badge HTML
         */
        getHealthStatusBadge: function(status) {
            const badges = {
                healthy: '<span class="badge badge-success">HEALTHY</span>',
                degraded: '<span class="badge badge-warning">DEGRADED</span>',
                unhealthy: '<span class="badge badge-error">UNHEALTHY</span>',
                unknown: '<span class="badge badge-info">UNKNOWN</span>'
            };
            return badges[status?.toLowerCase()] || badges.unknown;
        },

        /**
         * Get activity icon
         */
        getActivityIcon: function(action) {
            const icons = {
                login: '🔐',
                logout: '🚪',
                purchase: '🛒',
                refund: '💸',
                'route created': '➕',
                'route updated': '✏️',
                'route deleted': '🗑️',
                'user created': '👤',
                'user updated': '✏️',
                'user deleted': '🗑️'
            };
            return icons[action?.toLowerCase()] || '📝';
        },

        /**
         * Get activity badge class
         */
        getActivityBadgeClass: function(level) {
            const classes = {
                info: 'badge-info',
                warning: 'badge-warning',
                error: 'badge-error',
                success: 'badge-success'
            };
            return classes[level?.toLowerCase()] || 'badge-info';
        },

        /**
         * Get log status badge HTML
         */
        getLogStatusBadge: function(status) {
            const badges = {
                success: '<span class="badge badge-success">SUCCESS</span>',
                failed: '<span class="badge badge-error">FAILED</span>',
                pending: '<span class="badge badge-warning">PENDING</span>'
            };
            return badges[status?.toLowerCase()] || badges.success;
        },

        /**
         * Render revenue breakdown
         */
        renderRevenueBreakdown: function(breakdown) {
            if (!breakdown || typeof breakdown !== 'object') {
                return '<p class="subtle">No breakdown data available</p>';
            }

            return Object.entries(breakdown).map(([key, value]) => `
                <div style="display: flex; justify-content: space-between; padding: 4px 0;">
                    <span>${this.capitalize(key.replace(/_/g, ' '))}:</span>
                    <strong>NAD ${this.formatCurrency(value)}</strong>
                </div>
            `).join('');
        },

        /**
         * Get role badge class
         */
        getRoleBadgeClass: function(role) {
            const classes = {
                'SUPER_ADMIN': 'success',
                'TRANSPORT_ADMIN': 'warning',
                'ANALYTICS_ADMIN': 'info',
                'ADMIN': 'success',
                'USER': 'info',
                'OPERATOR': 'warning'
            };
            return classes[role?.toUpperCase()] || 'info';
        },

        /**
         * Apply masonry layout to stats grids
         */
        applyMasonryLayout: function(container) {
            // Wait for DOM to be fully rendered
            setTimeout(() => {
                const grids = container.querySelectorAll('.stats-grid');
                grids.forEach(grid => {
                    if (window.MasonryModule) {
                        window.MasonryModule.init(grid, {
                            method: 'grid', // Use grid-auto-rows masonry method
                            rowHeight: 50,  // 50px base row height
                            gap: 10,        // 10px gap between cards
                            responsive: true
                        });
                    }
                });
                
                // Dispatch event for other modules
                document.dispatchEvent(new CustomEvent('adminContentLoaded'));
            }, 50);
        },

        /**
         * Initialize admin view
         */
        initAdminView: function() {
            console.log('Admin view initialized');
            
            // Check authentication
            const isLoggedIn = window.APIModule?.isLoggedIn();
            if (!isLoggedIn) {
                console.log('Not authenticated, redirecting to login');
                window.location.hash = '#login';
                return;
            }

            // Set default values
            const userLimit = document.getElementById('userLimit');
            if (userLimit && !userLimit.value) userLimit.value = '20';

            const logsLimit = document.getElementById('logsLimit');
            if (logsLimit && !logsLimit.value) logsLimit.value = '50';

            const revenuePeriod = document.getElementById('revenuePeriod');
            if (revenuePeriod && !revenuePeriod.value) revenuePeriod.value = 'month';

            const logType = document.getElementById('logType');
            if (logType && !logType.value) logType.value = 'all';

            console.log('Admin view ready');
        }
    };

    console.log('Admin module loaded');
})();
