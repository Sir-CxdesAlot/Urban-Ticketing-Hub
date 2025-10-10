/**
 * Transport Service Module
 * Handles transport API testing and display functionality
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});

    /**
     * Display loading state in container
     */
    function showLoading(containerId) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = '<div class="loading">Loading...</div>';
        }
    }

    /**
     * Display error message in container
     */
    function showError(containerId, message) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `<div class="error-message">${message}</div>`;
        }
    }

    /**
     * Display empty state in container
     */
    function showEmpty(containerId, message) {
        const container = document.getElementById(containerId);
        if (container) {
            container.innerHTML = `<div class="info-message">${message}</div>`;
        }
    }

    /**
     * Fetch and display all routes
     */
    async function testFetchRoutes() {
        showLoading('routesResult');

        try {
            const api = App.api || window.APIModule;
            const routes = await api.fetchRoutes();
            
            if (routes.length === 0) {
                showError('routesResult', 'No routes found. Check if Docker services are running.');
                return;
            }

            let html = `<div class="results"><h3>Found ${routes.length} Routes</h3>`;
            routes.slice(0, 5).forEach(route => {
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>${route.name}</strong>
                            <span class="badge ${route.isActive ? 'badge-success' : 'badge-warning'}">
                                ${route.isActive ? 'Active' : 'Inactive'}
                            </span>
                        </div>
                        <div class="result-details">
                            <small>${route.startLocation} → ${route.endLocation}</small><br>
                            <small>Type: ${route.transportType} | Price: N$${route.basePrice}</small>
                        </div>
                    </div>
                `;
            });
            if (routes.length > 5) {
                html += `<p class="subtle" style="margin-top: 12px;">...and ${routes.length - 5} more</p>`;
            }
            html += '</div>';
            document.getElementById('routesResult').innerHTML = html;
        } catch (error) {
            showError('routesResult', `Error: ${error.message}`);
        }
    }

    /**
     * Search routes with criteria
     */
    async function testSearchRoutes() {
        showLoading('searchResult');

        const from = document.getElementById('searchFrom')?.value || '';
        const to = document.getElementById('searchTo')?.value || '';
        const type = document.getElementById('searchType')?.value || '';

        try {
            const api = App.api || window.APIModule;
            const routes = await api.searchRoutes({
                from: from || undefined,
                to: to || undefined,
                transportType: type || undefined
            });

            if (routes.length === 0) {
                showEmpty('searchResult', 'No routes match your search criteria.');
                return;
            }

            let html = `<div class="results"><h3>Found ${routes.length} Route${routes.length !== 1 ? 's' : ''}</h3>`;
            routes.forEach(route => {
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>${route.name}</strong>
                            <span class="badge badge-info">${route.transportType}</span>
                        </div>
                        <div class="result-details">
                            <small>${route.startLocation} → ${route.endLocation}</small><br>
                            <small>Price: N$${route.basePrice}</small>
                        </div>
                    </div>
                `;
            });
            html += '</div>';
            document.getElementById('searchResult').innerHTML = html;
        } catch (error) {
            showError('searchResult', `Error: ${error.message}`);
        }
    }

    /**
     * Fetch and display all trips
     */
    async function testFetchTrips() {
        showLoading('tripsResult');

        try {
            const api = App.api || window.APIModule;
            const trips = await api.fetchTrips();

            if (trips.length === 0) {
                showEmpty('tripsResult', 'No trips found.');
                return;
            }

            let html = `<div class="results"><h3>Found ${trips.length} Trips</h3>`;
            trips.slice(0, 5).forEach(trip => {
                const time = new Date(trip.departureTime).toLocaleString();
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Trip ${trip._id || trip.id}</strong>
                            <span class="badge badge-info">${trip.status}</span>
                        </div>
                        <div class="result-details">
                            <small>Departure: ${time}</small><br>
                            <small>Seats: ${trip.availableSeats}/${trip.totalSeats}</small>
                        </div>
                    </div>
                `;
            });
            if (trips.length > 5) {
                html += `<p class="subtle" style="margin-top: 12px;">...and ${trips.length - 5} more</p>`;
            }
            html += '</div>';
            document.getElementById('tripsResult').innerHTML = html;
        } catch (error) {
            showError('tripsResult', `Error: ${error.message}`);
        }
    }

    /**
     * Get upcoming trips in next 24 hours
     */
    async function testUpcomingTrips() {
        showLoading('upcomingResult');

        const limit = parseInt(document.getElementById('upcomingLimit')?.value) || 5;

        try {
            const api = App.api || window.APIModule;
            const trips = await api.getUpcomingTrips(limit);

            if (trips.length === 0) {
                showEmpty('upcomingResult', 'No upcoming trips in next 24 hours.');
                return;
            }

            let html = `<div class="results"><h3>${trips.length} Upcoming Trip${trips.length !== 1 ? 's' : ''}</h3>`;
            trips.forEach(trip => {
                const departTime = new Date(trip.departureTime);
                const now = new Date();
                const minutesUntil = Math.floor((departTime - now) / 1000 / 60);
                
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>${departTime.toLocaleTimeString()}</strong>
                            <span class="badge badge-success">In ${minutesUntil} min</span>
                        </div>
                        <div class="result-details">
                            <small>${trip.availableSeats} seats available</small>
                        </div>
                    </div>
                `;
            });
            html += '</div>';
            document.getElementById('upcomingResult').innerHTML = html;
        } catch (error) {
            showError('upcomingResult', `Error: ${error.message}`);
        }
    }

    /**
     * Get popular routes by trip count
     */
    async function testPopularRoutes() {
        showLoading('popularResult');

        const limit = parseInt(document.getElementById('popularLimit')?.value) || 5;

        try {
            const api = App.api || window.APIModule;
            const routes = await api.getPopularRoutes(limit);

            if (routes.length === 0) {
                showEmpty('popularResult', 'No routes found.');
                return;
            }

            let html = `<div class="results"><h3>Top ${routes.length} Route${routes.length !== 1 ? 's' : ''}</h3>`;
            routes.forEach((route, index) => {
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>#${index + 1}: ${route.name}</strong>
                            <span class="badge badge-info">${route.tripCount} trips</span>
                        </div>
                        <div class="result-details">
                            <small>${route.startLocation} → ${route.endLocation}</small><br>
                            <small>Price: N$${route.basePrice}</small>
                        </div>
                    </div>
                `;
            });
            html += '</div>';
            document.getElementById('popularResult').innerHTML = html;
        } catch (error) {
            showError('popularResult', `Error: ${error.message}`);
        }
    }

    /**
     * Get route schedule with trips grouped by date
     */
    async function testRouteSchedule() {
        const routeId = document.getElementById('scheduleRouteId')?.value;

        if (!routeId) {
            showError('scheduleResult', 'Please enter a route ID');
            return;
        }

        showLoading('scheduleResult');

        try {
            const api = App.api || window.APIModule;
            const schedule = await api.getRouteSchedule(routeId);

            if (!schedule.route) {
                showError('scheduleResult', 'Route not found');
                return;
            }

            let html = `<div class="results">`;
            html += `<h3>${schedule.route.name}</h3>`;
            html += `<p class="subtle">Total: ${schedule.totalTrips} trips | Available: ${schedule.availableTrips} trips</p>`;
            
            const dates = Object.keys(schedule.tripsByDate);
            if (dates.length === 0) {
                html += `<p class="info-message">No trips scheduled for this route.</p>`;
            } else {
                dates.slice(0, 3).forEach(date => {
                    html += `<h4 style="margin-top: 12px; color: var(--primary);">${date}</h4>`;
                    schedule.tripsByDate[date].slice(0, 3).forEach(trip => {
                        const time = new Date(trip.departureTime).toLocaleTimeString();
                        html += `
                            <div class="result-item">
                                <div class="result-header">
                                    <strong>${time}</strong>
                                    <span class="badge badge-success">${trip.availableSeats} seats</span>
                                </div>
                            </div>
                        `;
                    });
                });
                if (dates.length > 3) {
                    html += `<p class="subtle" style="margin-top: 12px;">...and ${dates.length - 3} more dates</p>`;
                }
            }
            
            html += '</div>';
            document.getElementById('scheduleResult').innerHTML = html;
        } catch (error) {
            showError('scheduleResult', `Error: ${error.message}`);
        }
    }

    /**
     * Initialize transport service view
     */
    async function initTransportView() {
        console.log('Transport Service view initializing...');
        
        // Auto-populate first route ID when routes are loaded
        try {
            const api = App.api || window.APIModule;
            const routes = await api.fetchRoutes();
            if (routes.length > 0) {
                const routeIdInput = document.getElementById('scheduleRouteId');
                if (routeIdInput) {
                    routeIdInput.value = routes[0]._id || routes[0].id;
                }
            }
        } catch (error) {
            console.error('Failed to pre-load route ID:', error);
        }

        console.log('Transport Service view ready!');
    }

    // Expose public API
    App.transport = {
        testFetchRoutes,
        testSearchRoutes,
        testFetchTrips,
        testUpcomingTrips,
        testPopularRoutes,
        testRouteSchedule,
        initTransportView
    };

    // Make functions available globally for onclick handlers
    window.testFetchRoutes = testFetchRoutes;
    window.testSearchRoutes = testSearchRoutes;
    window.testFetchTrips = testFetchTrips;
    window.testUpcomingTrips = testUpcomingTrips;
    window.testPopularRoutes = testPopularRoutes;
    window.testRouteSchedule = testRouteSchedule;

    console.log('Transport module loaded');
})();
