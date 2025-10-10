/**
 * API Integration Module
 * Handles communication with the microservices
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});

    // Configuration
    const CONFIG = {
        baseUrl: 'http://localhost',
        services: {
            passenger: ':8081',
            transport: ':8082',
            ticketing: ':8083',
            payment: ':8084',
            notification: ':8085',
            admin: ':8086'
        },
        endpoints: {
            // Passenger Service
            passengerRegister: '/api/v1/passenger/register',
            passengerLogin: '/api/v1/passenger/login',
            passengerProfile: '/api/v1/passenger/profile',
            passengerTickets: '/api/v1/passenger/tickets',
            
            // Transport Service
            transportRoutes: '/api/v1/transport/routes',
            transportTrips: '/api/v1/transport/trips',
            transportRoute: '/api/v1/transport/route',
            
            // Ticketing Service
            ticketPurchase: '/api/v1/ticketing/purchase',
            ticketValidate: '/api/v1/ticketing/validate',
            
            // Payment Service
            paymentProcess: '/api/v1/payment/process',
            paymentHistory: '/api/v1/payment/history',
            
            // Notification Service
            notificationsList: '/api/v1/notification/list',
            
            // Admin Service
            adminLogin: '/api/v1/admin/login',
            adminStats: '/api/v1/admin/stats'
        }
    };

    // Session state with role-based access control
    const session = {
        loggedIn: false,
        token: null,
        user: null,
        userId: null,
        userRole: 'GUEST', // 'GUEST', 'PASSENGER', 'ROUTE_OPERATOR', 'TRANSPORT_MANAGER', 'SUPER_ADMIN'
        userType: null, // Backward compatibility: 'passenger' or 'admin'
        guestMode: true
    };

    // Role hierarchy and permissions
    const ROLES = {
        GUEST: {
            level: 1,
            label: 'Guest',
            icon: '👁️',
            permissions: [
                'VIEW_PUBLIC_ROUTES',
                'SEARCH_ROUTES',
                'REGISTER'
            ]
        },
        PASSENGER: {
            level: 2,
            label: 'Passenger',
            icon: '👤',
            permissions: [
                'VIEW_PUBLIC_ROUTES',
                'SEARCH_ROUTES',
                'VIEW_ROUTES',
                'PURCHASE_TICKETS',
                'VIEW_OWN_TICKETS',
                'MANAGE_PROFILE',
                'PROCESS_PAYMENTS',
                'RECEIVE_NOTIFICATIONS',
                'REQUEST_REFUNDS'
            ]
        },
        ROUTE_OPERATOR: {
            level: 3,
            label: 'Route Operator',
            icon: '🎫',
            permissions: [
                'VALIDATE_TICKETS',
                'VIEW_ASSIGNED_ROUTES',
                'UPDATE_TRIP_STATUS',
                'REPORT_INCIDENTS',
                'MONITOR_CAPACITY',
                'SEND_OPERATIONAL_ALERTS'
            ]
        },
        TRANSPORT_MANAGER: {
            level: 4,
            label: 'Transport Manager',
            icon: '🚌',
            permissions: [
                'VALIDATE_TICKETS',
                'VIEW_ASSIGNED_ROUTES',
                'UPDATE_TRIP_STATUS',
                'REPORT_INCIDENTS',
                'MONITOR_CAPACITY',
                'SEND_OPERATIONAL_ALERTS',
                'CREATE_ROUTES',
                'MANAGE_ROUTES',
                'SCHEDULE_TRIPS',
                'PUBLISH_DISRUPTIONS',
                'VIEW_TRANSPORT_ANALYTICS',
                'MANAGE_FLEET',
                'SEND_TRANSPORT_NOTIFICATIONS',
                'VIEW_PASSENGER_STATS',
                'GENERATE_REPORTS'
            ]
        },
        SUPER_ADMIN: {
            level: 5,
            label: 'Super Admin',
            icon: '👨‍💼',
            permissions: [
                'ALL_PERMISSIONS',
                'MANAGE_USERS',
                'ASSIGN_ROLES',
                'SYSTEM_CONFIGURATION',
                'VIEW_AUDIT_LOGS',
                'MONITOR_SERVICES',
                'MANAGE_PLATFORM',
                'OVERRIDE_OPERATIONS',
                'BROADCAST_NOTIFICATIONS'
            ]
        }
    };

    // Permission checking function
    function hasPermission(permission) {
        if (!session.loggedIn && session.userRole !== 'GUEST') {
            return false;
        }
        
        const role = ROLES[session.userRole];
        if (!role) return false;
        
        // Super admin has all permissions
        if (session.userRole === 'SUPER_ADMIN') {
            return true;
        }
        
        return role.permissions.includes(permission);
    }

    // Role hierarchy check
    function hasRoleLevel(requiredLevel) {
        const userLevel = ROLES[session.userRole]?.level || 0;
        return userLevel >= requiredLevel;
    }

    // Check if user has minimum role
    function hasMinimumRole(requiredRole) {
        const requiredLevel = ROLES[requiredRole]?.level || 0;
        const userLevel = ROLES[session.userRole]?.level || 0;
        return userLevel >= requiredLevel;
    }

    // Load session from localStorage
    function loadSession() {
        try {
            const saved = localStorage.getItem('ticketing_session');
            if (saved) {
                const data = JSON.parse(saved);
                Object.assign(session, data);
                console.log('Session loaded:', session.userRole);
            } else {
                // Initialize as guest if no session exists
                initGuestMode();
            }
        } catch (error) {
            console.error('Failed to load session:', error);
            initGuestMode();
        }
    }

    // Initialize guest mode
    function initGuestMode() {
        session.loggedIn = false;
        session.token = null;
        session.user = null;
        session.userId = null;
        session.userRole = 'GUEST';
        session.userType = null;
        session.guestMode = true;
        console.log('Initialized as GUEST');
    }

    // Save session to localStorage
    function saveSession() {
        try {
            localStorage.setItem('ticketing_session', JSON.stringify(session));
        } catch (error) {
            console.error('Failed to save session:', error);
        }
    }

    // Clear session
    function clearSession() {
        localStorage.removeItem('ticketing_session');
        initGuestMode();
        console.log('Session cleared - reverted to GUEST');
    }

    /**
     * Make API request with better error handling
     * @param {string} service - Service name (e.g., 'transport')
     * @param {string} endpoint - API endpoint (e.g., '/api/v1/transport/routes')
     * @param {object} options - Fetch options
     */
    async function apiRequest(service, endpoint, options = {}) {
        const url = `${CONFIG.baseUrl}${CONFIG.services[service]}${endpoint}`;
        
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers
        };

        if (session.token) {
            headers['Authorization'] = `Bearer ${session.token}`;
        }

        try {
            console.log(`API Request: ${options.method || 'GET'} ${url}`);
            
            const response = await fetch(url, {
                ...options,
                headers,
                mode: 'cors'
            });

            // Handle different response types
            const contentType = response.headers.get('content-type');
            let data;
            
            if (contentType && contentType.includes('application/json')) {
                data = await response.json();
            } else {
                data = await response.text();
            }

            if (!response.ok) {
                const error = new Error(data.message || `HTTP ${response.status}: ${response.statusText}`);
                error.status = response.status;
                error.data = data;
                throw error;
            }

            console.log(`API Response: ${url}`, data);
            return data;
            
        } catch (error) {
            console.error(`API request failed: ${url}`, error);
            
            // Check if it's a network error (services not running)
            if (error.message === 'Failed to fetch' || error.name === 'TypeError') {
                error.isNetworkError = true;
                error.message = 'Unable to connect to service. Please ensure Docker containers are running.';
            }
            
            throw error;
        }
    }

    /**
     * Passenger Authentication
     */
    async function passengerRegister(userData) {
        try {
            const response = await apiRequest('passenger', CONFIG.endpoints.passengerRegister, {
                method: 'POST',
                body: JSON.stringify(userData)
            });
            
            // Auto-login after registration if token is provided
            if (response.token) {
                session.loggedIn = true;
                session.token = response.token;
                session.user = response.user;
                session.userId = response.user?.id;
                session.userRole = 'PASSENGER';
                session.userType = 'passenger';
                session.guestMode = false;
                saveSession();
                console.log('Passenger registered and logged in successfully');
            }
            
            return { success: true, data: response };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async function passengerLogin(email, password) {
        try {
            const response = await apiRequest('passenger', CONFIG.endpoints.passengerLogin, {
                method: 'POST',
                body: JSON.stringify({ email, password })
            });
            
            if (response.token) {
                session.loggedIn = true;
                session.token = response.token;
                session.user = response.user;
                session.userId = response.user?.id;
                session.userRole = 'PASSENGER';
                session.userType = 'passenger'; // Backward compatibility
                session.guestMode = false;
                saveSession();
                console.log('Passenger logged in successfully');
            }
            
            return { success: true, data: response };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async function passengerLogout() {
        clearSession();
        return { success: true };
    }

    /**
     * Admin/Staff Authentication
     */
    async function adminLogin(email, password) {
        try {
            const response = await apiRequest('admin', CONFIG.endpoints.adminLogin, {
                method: 'POST',
                body: JSON.stringify({ email, password })
            });
            
            if (response.token) {
                session.loggedIn = true;
                session.token = response.token;
                session.user = response.user;
                session.userId = response.user?.id;
                
                // Determine role from backend response or default to SUPER_ADMIN
                session.userRole = response.user?.role || 'SUPER_ADMIN';
                session.userType = 'admin'; // Backward compatibility
                session.guestMode = false;
                
                saveSession();
                console.log(`Admin logged in successfully - Role: ${session.userRole}`);
            }
            
            return { success: true, data: response };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    async function fetchPassengerProfile() {
        try {
            return await apiRequest('passenger', CONFIG.endpoints.passengerProfile, {
                method: 'GET'
            });
        } catch (error) {
            console.error('Failed to fetch passenger profile:', error);
            return null;
        }
    }

    /**
     * ==========================================
     * TRANSPORT SERVICE API
     * ==========================================
     */

    /**
     * Fetch all routes
     * @returns {Promise<Array>} Array of route objects
     */
    async function fetchRoutes() {
        try {
            const routes = await apiRequest('transport', CONFIG.endpoints.transportRoutes);
            return Array.isArray(routes) ? routes : [];
        } catch (error) {
            console.error('Failed to fetch routes:', error);
            return [];
        }
    }

    /**
     * Fetch a specific route by ID
     * @param {string} routeId - The route ID
     * @returns {Promise<Object|null>} Route object or null
     */
    async function fetchRouteById(routeId) {
        try {
            const route = await apiRequest('transport', `${CONFIG.endpoints.transportRoute}/${routeId}`);
            return route;
        } catch (error) {
            console.error(`Failed to fetch route ${routeId}:`, error);
            return null;
        }
    }

    /**
     * Search routes by criteria
     * @param {Object} criteria - Search criteria
     * @param {string} criteria.from - Starting location
     * @param {string} criteria.to - Destination location
     * @param {string} criteria.transportType - Type of transport (BUS, TRAIN, etc.)
     * @returns {Promise<Array>} Filtered routes
     */
    async function searchRoutes(criteria = {}) {
        try {
            const allRoutes = await fetchRoutes();
            let filtered = allRoutes;

            // Filter by start location
            if (criteria.from) {
                filtered = filtered.filter(route => 
                    route.startLocation?.toLowerCase().includes(criteria.from.toLowerCase())
                );
            }

            // Filter by end location
            if (criteria.to) {
                filtered = filtered.filter(route => 
                    route.endLocation?.toLowerCase().includes(criteria.to.toLowerCase())
                );
            }

            // Filter by transport type
            if (criteria.transportType) {
                filtered = filtered.filter(route => 
                    route.transportType?.toLowerCase() === criteria.transportType.toLowerCase()
                );
            }

            // Filter active only
            if (criteria.activeOnly !== false) {
                filtered = filtered.filter(route => route.isActive);
            }

            console.log(`Search routes: ${filtered.length} results from ${allRoutes.length} total`);
            return filtered;
        } catch (error) {
            console.error('Failed to search routes:', error);
            return [];
        }
    }

    /**
     * Get available transport types
     * @returns {Promise<Array>} Array of transport types
     */
    async function getTransportTypes() {
        try {
            const routes = await fetchRoutes();
            const types = [...new Set(routes.map(route => route.transportType).filter(Boolean))];
            return types.sort();
        } catch (error) {
            console.error('Failed to get transport types:', error);
            return ['BUS', 'TRAIN', 'TAXI', 'SHUTTLE']; // Fallback defaults
        }
    }

    /**
     * Fetch all trips
     * @returns {Promise<Array>} Array of trip objects
     */
    async function fetchTrips() {
        try {
            const trips = await apiRequest('transport', CONFIG.endpoints.transportTrips);
            return Array.isArray(trips) ? trips : [];
        } catch (error) {
            console.error('Failed to fetch trips:', error);
            return [];
        }
    }

    /**
     * Fetch a specific trip by ID
     * @param {string} tripId - The trip ID
     * @returns {Promise<Object|null>} Trip object or null
     */
    async function fetchTripById(tripId) {
        try {
            const trips = await fetchTrips();
            const trip = trips.find(t => (t._id || t.id) === tripId);
            return trip || null;
        } catch (error) {
            console.error(`Failed to fetch trip ${tripId}:`, error);
            return null;
        }
    }

    /**
     * Fetch trips for a specific route
     * @param {string} routeId - The route ID
     * @returns {Promise<Array>} Array of trips for the route
     */
    async function fetchTripsByRoute(routeId) {
        try {
            const allTrips = await fetchTrips();
            const routeTrips = allTrips.filter(trip => trip.routeId === routeId);
            console.log(`Found ${routeTrips.length} trips for route ${routeId}`);
            return routeTrips;
        } catch (error) {
            console.error(`Failed to fetch trips for route ${routeId}:`, error);
            return [];
        }
    }

    /**
     * Search/filter trips by criteria
     * @param {Object} criteria - Search criteria
     * @param {string} criteria.routeId - Filter by route ID
     * @param {string} criteria.date - Filter by date (YYYY-MM-DD)
     * @param {string} criteria.status - Filter by status (SCHEDULED, IN_TRANSIT, COMPLETED, CANCELLED)
     * @param {boolean} criteria.availableOnly - Only show trips with available seats
     * @returns {Promise<Array>} Filtered trips
     */
    async function searchTrips(criteria = {}) {
        try {
            const allTrips = await fetchTrips();
            let filtered = allTrips;

            // Filter by route ID
            if (criteria.routeId) {
                filtered = filtered.filter(trip => trip.routeId === criteria.routeId);
            }

            // Filter by date
            if (criteria.date) {
                filtered = filtered.filter(trip => {
                    const tripDate = trip.departureTime?.split('T')[0];
                    return tripDate === criteria.date;
                });
            }

            // Filter by status
            if (criteria.status) {
                filtered = filtered.filter(trip => 
                    trip.status?.toUpperCase() === criteria.status.toUpperCase()
                );
            }

            // Filter available only
            if (criteria.availableOnly) {
                filtered = filtered.filter(trip => trip.availableSeats > 0);
            }

            console.log(`Search trips: ${filtered.length} results from ${allTrips.length} total`);
            return filtered;
        } catch (error) {
            console.error('Failed to search trips:', error);
            return [];
        }
    }

    /**
     * Get trip schedule for a specific route with detailed information
     * @param {string} routeId - The route ID
     * @returns {Promise<Object>} Schedule information with route and trips
     */
    async function getRouteSchedule(routeId) {
        try {
            const [route, trips] = await Promise.all([
                fetchRouteById(routeId),
                fetchTripsByRoute(routeId)
            ]);

            if (!route) {
                throw new Error('Route not found');
            }

            // Group trips by date
            const tripsByDate = {};
            trips.forEach(trip => {
                const date = trip.departureTime?.split('T')[0] || 'Unknown';
                if (!tripsByDate[date]) {
                    tripsByDate[date] = [];
                }
                tripsByDate[date].push(trip);
            });

            // Sort trips within each date
            Object.keys(tripsByDate).forEach(date => {
                tripsByDate[date].sort((a, b) => 
                    new Date(a.departureTime) - new Date(b.departureTime)
                );
            });

            return {
                route,
                trips,
                tripsByDate,
                totalTrips: trips.length,
                availableTrips: trips.filter(t => t.availableSeats > 0).length
            };
        } catch (error) {
            console.error(`Failed to get schedule for route ${routeId}:`, error);
            return { route: null, trips: [], tripsByDate: {}, totalTrips: 0, availableTrips: 0 };
        }
    }

    /**
     * Get popular routes (most trips scheduled)
     * @param {number} limit - Number of routes to return
     * @returns {Promise<Array>} Top routes with trip counts
     */
    async function getPopularRoutes(limit = 5) {
        try {
            const [routes, trips] = await Promise.all([fetchRoutes(), fetchTrips()]);
            
            // Count trips per route
            const tripCounts = {};
            trips.forEach(trip => {
                tripCounts[trip.routeId] = (tripCounts[trip.routeId] || 0) + 1;
            });

            // Add trip count to routes and sort
            const routesWithCounts = routes.map(route => ({
                ...route,
                tripCount: tripCounts[route._id || route.id] || 0
            }));

            return routesWithCounts
                .sort((a, b) => b.tripCount - a.tripCount)
                .slice(0, limit);
        } catch (error) {
            console.error('Failed to get popular routes:', error);
            return [];
        }
    }

    /**
     * Get upcoming trips (next 24 hours)
     * @param {number} limit - Maximum number of trips to return
     * @returns {Promise<Array>} Upcoming trips
     */
    async function getUpcomingTrips(limit = 10) {
        try {
            const allTrips = await fetchTrips();
            const now = new Date();
            const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

            const upcoming = allTrips
                .filter(trip => {
                    const departureTime = new Date(trip.departureTime);
                    return departureTime >= now && 
                           departureTime <= tomorrow && 
                           trip.status === 'SCHEDULED';
                })
                .sort((a, b) => new Date(a.departureTime) - new Date(b.departureTime))
                .slice(0, limit);

            console.log(`Found ${upcoming.length} upcoming trips in next 24 hours`);
            return upcoming;
        } catch (error) {
            console.error('Failed to get upcoming trips:', error);
            return [];
        }
    }

    /**
     * Fetch passenger tickets
     */
    async function fetchTickets() {
        try {
            if (!session.loggedIn) {
                throw new Error('Please log in to view tickets');
            }
            const tickets = await apiRequest('passenger', CONFIG.endpoints.passengerTickets);
            return Array.isArray(tickets) ? tickets : [];
        } catch (error) {
            console.error('Failed to fetch tickets:', error);
            return [];
        }
    }

    /**
     * Display routes in the UI
     */
    async function displayRoutes() {
        const routesGrid = document.getElementById('routesGrid');
        const routeCount = document.getElementById('routeCount');
        
        if (!routesGrid) return;

        routesGrid.innerHTML = '<p class="info-message">Loading routes...</p>';

        try {
            const routes = await fetchRoutes();
            routeCount.textContent = routes.length;

            if (routes.length === 0) {
                routesGrid.innerHTML = '<p class="info-message">No routes available. Start Docker services to load data.</p>';
                return;
            }

            routesGrid.innerHTML = routes.map(route => `
                <div class="card">
                    <div class="card-header">
                        <h3 class="card-title">${escapeHtml(route.name)}</h3>
                        <span class="badge ${route.isActive ? 'badge-success' : 'badge-error'}">
                            ${route.isActive ? 'Active' : 'Inactive'}
                        </span>
                    </div>
                    <div class="card-body">
                        <p><strong>From:</strong> ${escapeHtml(route.startLocation)}</p>
                        <p><strong>To:</strong> ${escapeHtml(route.endLocation)}</p>
                        <p><strong>Type:</strong> ${escapeHtml(route.transportType)}</p>
                        <p><strong>Price:</strong> N$${route.basePrice}</p>
                        ${route.intermediateStops && route.intermediateStops.length > 0 ? 
                            `<p><strong>Stops:</strong> ${route.intermediateStops.join(', ')}</p>` : ''}
                    </div>
                    <div class="card-actions">
                        <button class="btn btn-primary btn-sm" onclick="window.APIModule.viewTripSchedule('${route._id || route.id}')">
                            View Schedules
                        </button>
                    </div>
                </div>
            `).join('');
        } catch (error) {
            routesGrid.innerHTML = `
                <p class="info-message error-message">
                    ⚠️ Unable to connect to Transport Service. 
                    Please ensure Docker services are running: <code>docker-compose up</code>
                </p>
            `;
        }
    }

    /**
     * Display trips in the UI
     */
    async function displayTrips() {
        const tripsTable = document.getElementById('tripsTable');
        const tripCount = document.getElementById('tripCount');
        
        if (!tripsTable) return;

        const tbody = tripsTable.querySelector('tbody');
        tbody.innerHTML = '<tr><td colspan="6">Loading trips...</td></tr>';

        try {
            const [trips, routes] = await Promise.all([fetchTrips(), fetchRoutes()]);
            tripCount.textContent = trips.length;

            // Create route lookup map
            const routeMap = {};
            routes.forEach(route => {
                const id = route._id || route.id;
                if (id) routeMap[id] = route;
            });

            if (trips.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6">No trips scheduled. Start Docker services to load data.</td></tr>';
                return;
            }

            tbody.innerHTML = trips.map(trip => {
                const route = routeMap[trip.routeId] || { name: 'Unknown Route' };
                const statusClass = trip.status === 'SCHEDULED' ? 'badge-success' : 
                                  trip.status === 'CANCELLED' ? 'badge-error' : 'badge-warning';

                return `
                    <tr>
                        <td>${escapeHtml(route.name)}</td>
                        <td>${escapeHtml(trip.departureTime)}</td>
                        <td>${escapeHtml(trip.arrivalTime)}</td>
                        <td>${trip.availableSeats}/${trip.totalSeats}</td>
                        <td><span class="badge ${statusClass}">${trip.status}</span></td>
                        <td>
                            <button class="btn btn-primary btn-sm" 
                                    ${trip.availableSeats === 0 ? 'disabled' : ''}
                                    onclick="window.APIModule.purchaseTicket('${trip._id || trip.id}')">
                                ${trip.availableSeats > 0 ? 'Book' : 'Full'}
                            </button>
                        </td>
                    </tr>
                `;
            }).join('');
        } catch (error) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="6" class="error-message">
                        ⚠️ Unable to connect to Transport Service. 
                        Please ensure Docker services are running.
                    </td>
                </tr>
            `;
        }
    }

    /**
     * View trip schedule for a specific route
     */
    function viewTripSchedule(routeId) {
        // Scroll to trips table
        const tripsTable = document.getElementById('tripsTable');
        if (tripsTable) {
            tripsTable.scrollIntoView({ behavior: 'smooth' });
        }
        console.log('View schedule for route:', routeId);
    }

    /**
     * Purchase ticket - now supports both modal and direct calls
     */
    async function purchaseTicket(tripOrData) {
        // If called with just tripId (from old button clicks), open modal
        if (typeof tripOrData === 'string') {
            const tripId = tripOrData;
            console.log('Opening ticket modal for trip:', tripId);
            
            // Find the trip data
            const trips = await fetchTrips();
            const trip = trips.find(t => (t._id || t.id) === tripId);
            
            if (!trip) {
                alert('Trip not found');
                return { success: false, message: 'Trip not found' };
            }

            // Open modal if available
            const modals = window.Modals || window.App?.modals;
            if (modals && typeof modals.openTicketModal === 'function') {
                modals.openTicketModal(trip);
            } else {
                alert('Please log in first to purchase tickets');
            }
            return { success: true };
        }

        // If called with purchase data object (from modal form)
        const { tripId, quantity, paymentMethod } = tripOrData;

        if (!session.loggedIn) {
            return { success: false, message: 'Please log in to purchase tickets' };
        }

        try {
            console.log('Purchasing ticket:', { tripId, quantity, paymentMethod });

            // Call ticketing service
            const result = await apiRequest('ticketing', CONFIG.endpoints.ticketPurchase, {
                method: 'POST',
                body: JSON.stringify({
                    tripId,
                    passengerId: session.user?.id,
                    quantity,
                    paymentMethod
                })
            });

            if (result && result.ticketId) {
                return {
                    success: true,
                    message: 'Ticket purchased successfully',
                    ticket: result
                };
            } else {
                return {
                    success: false,
                    message: result?.message || 'Purchase failed'
                };
            }
        } catch (error) {
            console.error('Ticket purchase error:', error);
            return {
                success: false,
                message: error.message || 'Failed to purchase ticket'
            };
        }
    }

    /**
     * Escape HTML to prevent XSS
     */
    function escapeHtml(unsafe) {
        if (!unsafe) return '';
        return unsafe
            .toString()
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }

    // ========================================================================
    // ADMIN API FUNCTIONS
    // ========================================================================

    /**
     * Fetch admin system statistics
     */
    async function fetchAdminSystemStats() {
        try {
            if (!hasMinimumRole('OPERATOR')) {
                throw new Error('Insufficient permissions. Admin access required.');
            }
            const stats = await apiRequest('admin', '/api/v1/admin/dashboard');
            return { success: true, data: stats };
        } catch (error) {
            console.error('Failed to fetch admin system stats:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Fetch admin users list
     */
    async function fetchAdminUsers(params = {}) {
        try {
            if (!hasMinimumRole('OPERATOR')) {
                throw new Error('Insufficient permissions. Admin access required.');
            }
            const queryString = new URLSearchParams(params).toString();
            const users = await apiRequest('admin', `/api/v1/admin/admin-users${queryString ? '?' + queryString : ''}`);
            return { success: true, data: users };
        } catch (error) {
            console.error('Failed to fetch admin users:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Fetch admin routes for management
     * Note: Admin service doesn't have route management, using transport service instead
     */
    async function fetchAdminRoutes(params = {}) {
        try {
            if (!hasMinimumRole('OPERATOR')) {
                throw new Error('Insufficient permissions. Admin access required.');
            }
            // Use transport service routes since admin service doesn't have this endpoint
            const routes = await fetchRoutes();
            return { success: true, data: routes };
        } catch (error) {
            console.error('Failed to fetch admin routes:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Fetch admin service health status
     */
    async function fetchAdminServiceHealth() {
        try {
            if (!hasMinimumRole('OPERATOR')) {
                throw new Error('Insufficient permissions. Admin access required.');
            }
            const health = await apiRequest('admin', '/api/v1/admin/health');
            return { success: true, data: health };
        } catch (error) {
            console.error('Failed to fetch service health:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Fetch admin revenue analytics
     * Note: Admin service only has usage reports, not revenue-specific
     */
    async function fetchAdminRevenueAnalytics(params = {}) {
        try {
            if (!hasMinimumRole('OPERATOR')) {
                throw new Error('Insufficient permissions. Admin access required.');
            }
            // Use usage report endpoint which includes revenue data
            const queryString = new URLSearchParams(params).toString();
            const report = await apiRequest('admin', `/api/v1/admin/reports/usage${queryString ? '?' + queryString : ''}`);
            return { success: true, data: report };
        } catch (error) {
            console.error('Failed to fetch revenue analytics:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Fetch admin activity logs
     * Note: Admin service doesn't have logs endpoint, using disruptions as alternative
     */
    async function fetchAdminActivityLogs(params = {}) {
        try {
            if (!hasMinimumRole('OPERATOR')) {
                throw new Error('Insufficient permissions. Admin access required.');
            }
            // Use disruptions endpoint as a proxy for activity logs
            const disruptions = await apiRequest('admin', '/api/v1/admin/disruptions');
            return { success: true, data: disruptions };
        } catch (error) {
            console.error('Failed to fetch activity logs:', error);
            return { success: false, message: error.message };
        }
    }

    /**
     * Initialize API module
     */
    function init() {
        console.log('API module initializing...');
        
        // Load saved session
        loadSession();
        
        // Only auto-load data if we're on a page that needs it
        // Note: Routes are now handled by route-browser.js module
        const tripsTable = document.getElementById('tripsTable');
        
        if (tripsTable) {
            // Load initial trips data
            displayTrips();

            // Refresh data every 30 seconds
            setInterval(() => {
                displayTrips();
            }, 30000);
        }

        const roleInfo = ROLES[session.userRole];
        console.log(`API module initialized. Role: ${roleInfo?.label || 'Unknown'} (${session.userRole})`);
        console.log(`Session: ${session.loggedIn ? 'Logged in' : 'Guest mode'}`);
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Export to App namespace and window for compatibility
    const api = {
        // Constants
        ROLES,
        
        // Session management
        session,
        loadSession,
        saveSession,
        clearSession,
        initGuestMode,
        
        // Permission checking
        hasPermission,
        hasRoleLevel,
        hasMinimumRole,
        
        // Authentication
        passengerRegister,
        passengerLogin,
        passengerLogout,
        adminLogin,
        fetchPassengerProfile,
        
        // Transport Service - Routes
        fetchRoutes,
        fetchRouteById,
        searchRoutes,
        getTransportTypes,
        getPopularRoutes,
        getRouteSchedule,
        
        // Transport Service - Trips
        fetchTrips,
        fetchTripById,
        fetchTripsByRoute,
        searchTrips,
        getUpcomingTrips,
        
        // Ticketing
        fetchTickets,
        
        // Admin API Functions
        fetchAdminSystemStats,
        fetchAdminUsers,
        fetchAdminRoutes,
        fetchAdminServiceHealth,
        fetchAdminRevenueAnalytics,
        fetchAdminActivityLogs,
        
        // UI Functions
        displayRoutes,
        displayTrips,
        viewTripSchedule,
        purchaseTicket,
        
        // Low-level
        apiRequest
    };
    
    App.api = api;
    window.APIModule = api; // Backward compatibility
})();
