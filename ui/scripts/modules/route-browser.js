/**
 * Route Browser Module
 * Passenger-friendly route browsing and ticket purchasing
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});

    const RouteBrowser = {
        currentRoute: null,
        currentTrip: null,

        /**
         * Initialize route browser
         */
        init() {
            // Close button for route trips modal
            document.getElementById('closeRouteTripsModal')?.addEventListener('click', () => {
                this.closeRouteTripsModal();
            });

            // Overlay click to close
            document.getElementById('routeTripsOverlay')?.addEventListener('click', () => {
                this.closeRouteTripsModal();
            });

            console.log('✓ Route Browser initialized');
        },

        /**
         * Display routes in passenger view
         */
        async displayRoutes() {
            const container = document.getElementById('routesGrid');
            const countEl = document.getElementById('routeCount');

            if (!container) return;

            try {
                // Show loading
                container.innerHTML = '<div class="loading">Loading routes...</div>';

                // Fetch routes from API
                const api = App.api || window.APIModule;
                const routes = await api.fetchRoutes();

                if (!routes || routes.length === 0) {
                    container.innerHTML = `
                        <div class="info-message">
                            <p>No routes available at the moment.</p>
                            <p class="subtle">Please check back later.</p>
                        </div>
                    `;
                    if (countEl) countEl.textContent = '0';
                    return;
                }

                // Filter active routes
                const activeRoutes = routes.filter(r => r.isActive !== false);

                // Update count
                if (countEl) countEl.textContent = String(activeRoutes.length);

                // Render route cards
                let html = '';
                activeRoutes.forEach(route => {
                    html += this.renderRouteCard(route);
                });

                container.innerHTML = html;

                // Add click listeners to route cards
                this.attachRouteClickListeners();

                console.log(`✓ Displayed ${activeRoutes.length} routes`);
            } catch (error) {
                console.error('Error displaying routes:', error);
                container.innerHTML = `
                    <div class="error-message">
                        <p>Unable to load routes. Please try again.</p>
                        <p class="subtle">${error.message}</p>
                    </div>
                `;
                if (countEl) countEl.textContent = '0';
            }
        },

        /**
         * Render a single route card
         */
        renderRouteCard(route) {
            const transportIcons = {
                BUS: '🚌',
                TAXI: '🚕',
                TRAIN: '🚆',
                SHUTTLE: '🚐'
            };

            const icon = transportIcons[route.transportType] || '🚌';
            const price = route.basePrice ? `N$${route.basePrice.toFixed(2)}` : 'Price TBA';

            return `
                <div class="route-card" data-route-id="${route._id || route.id}" style="cursor: pointer;">
                    <div class="route-icon" style="font-size: 2.5rem; text-align: center; margin-bottom: 12px;">
                        ${icon}
                    </div>
                    <h3 class="route-name" style="margin-bottom: 8px; font-size: 1.1rem; font-weight: 600;">
                        ${this.escapeHtml(route.name || 'Unnamed Route')}
                    </h3>
                    <div class="route-locations" style="margin-bottom: 12px;">
                        <p style="font-size: 0.9rem; color: var(--text-muted);">
                            <strong>${this.escapeHtml(route.startLocation || 'Start')}</strong> 
                            → 
                            <strong>${this.escapeHtml(route.endLocation || 'End')}</strong>
                        </p>
                    </div>
                    <div class="route-details" style="display: flex; justify-content: space-between; align-items: center; margin-top: 12px;">
                        <span class="badge badge-info">${this.escapeHtml(route.transportType || 'BUS')}</span>
                        <span style="font-weight: 600; color: var(--primary);">${price}</span>
                    </div>
                    <div style="margin-top: 16px; text-align: center;">
                        <button class="btn btn-primary btn-sm view-trips-btn" style="width: 100%;">
                            View Schedules →
                        </button>
                    </div>
                </div>
            `;
        },

        /**
         * Attach click listeners to route cards
         */
        attachRouteClickListeners() {
            const routeCards = document.querySelectorAll('.route-card');
            routeCards.forEach(card => {
                card.addEventListener('click', async (e) => {
                    const routeId = card.dataset.routeId;
                    if (routeId) {
                        await this.openRouteTripsModal(routeId);
                    }
                });
            });
        },

        /**
         * Open modal showing trips for a specific route
         */
        async openRouteTripsModal(routeId) {
            const modal = document.getElementById('routeTripsModal');
            if (!modal) return;

            try {
                // Fetch route details
                const api = App.api || window.APIModule;
                const routes = await api.fetchRoutes();
                const route = routes.find(r => (r._id || r.id) === routeId);

                if (!route) {
                    throw new Error('Route not found');
                }

                this.currentRoute = route;

                // Update modal title
                document.getElementById('routeTripsTitle').textContent = route.name || 'Route Trips';
                document.getElementById('routeTripsSubtitle').textContent = 
                    `${route.startLocation} → ${route.endLocation} • ${route.transportType}`;

                // Show modal
                modal.removeAttribute('hidden');
                document.body.style.overflow = 'hidden';

                // Show loading state
                this.showTripsLoading();

                // Fetch trips for this route
                const trips = await api.fetchTripsByRoute(routeId);

                if (!trips || trips.length === 0) {
                    this.showTripsEmpty();
                } else {
                    this.displayTrips(trips);
                }
            } catch (error) {
                console.error('Error opening route trips modal:', error);
                this.showTripsError(error.message);
            }
        },

        /**
         * Close route trips modal
         */
        closeRouteTripsModal() {
            const modal = document.getElementById('routeTripsModal');
            if (modal) {
                modal.setAttribute('hidden', '');
                document.body.style.overflow = '';
                this.currentRoute = null;
            }
        },

        /**
         * Show loading state in trips modal
         */
        showTripsLoading() {
            document.getElementById('tripsLoadingState')?.removeAttribute('hidden');
            document.getElementById('tripsErrorState')?.setAttribute('hidden', '');
            document.getElementById('tripsEmptyState')?.setAttribute('hidden', '');
            document.getElementById('tripsList').innerHTML = '';
        },

        /**
         * Show error state in trips modal
         */
        showTripsError(message) {
            document.getElementById('tripsLoadingState')?.setAttribute('hidden', '');
            const errorEl = document.getElementById('tripsErrorState');
            if (errorEl) {
                errorEl.textContent = message;
                errorEl.removeAttribute('hidden');
            }
            document.getElementById('tripsEmptyState')?.setAttribute('hidden', '');
            document.getElementById('tripsList').innerHTML = '';
        },

        /**
         * Show empty state in trips modal
         */
        showTripsEmpty() {
            document.getElementById('tripsLoadingState')?.setAttribute('hidden', '');
            document.getElementById('tripsErrorState')?.setAttribute('hidden', '');
            document.getElementById('tripsEmptyState')?.removeAttribute('hidden');
            document.getElementById('tripsList').innerHTML = '';
        },

        /**
         * Display trips in modal
         */
        displayTrips(trips) {
            document.getElementById('tripsLoadingState')?.setAttribute('hidden', '');
            document.getElementById('tripsErrorState')?.setAttribute('hidden', '');
            document.getElementById('tripsEmptyState')?.setAttribute('hidden', '');

            const container = document.getElementById('tripsList');
            if (!container) return;

            let html = '<div class="trips-grid">';

            if (trips.length > 0) {
                console.log('📋 Sample trip object:', trips[0]);
                console.log('📋 Trip object keys:', Object.keys(trips[0]));
                console.log('📋 Trip ID field (_id):', trips[0]._id);
                console.log('📋 Trip ID field (id):', trips[0].id);
            }

            trips.forEach(trip => {
                html += this.renderTripCard(trip);
            });

            html += '</div>';
            container.innerHTML = html;

            // Attach purchase button listeners
            this.attachPurchaseListeners();
        },

        /**
         * Render a single trip card
         */
        renderTripCard(trip) {
            console.log('🎫 Rendering trip card:', { 
                tripId: trip._id || trip.id, 
                hasId: !!(trip._id || trip.id),
                trip 
            });
            
            const departureTime = this.formatDateTime(trip.departureTime);
            const arrivalTime = this.formatDateTime(trip.arrivalTime);
            const availableSeats = trip.availableSeats || 0;
            const totalSeats = trip.capacity || 50;
            const seatsPercentage = (availableSeats / totalSeats) * 100;

            let seatsBadge = 'badge-success';
            let seatsText = `${availableSeats} seats available`;

            if (availableSeats === 0) {
                seatsBadge = 'badge-danger';
                seatsText = 'Fully Booked';
            } else if (seatsPercentage < 20) {
                seatsBadge = 'badge-warning';
                seatsText = `Only ${availableSeats} seats left!`;
            }

            const isAvailable = availableSeats > 0;
            const tripStatus = trip.status || 'SCHEDULED';

            return `
                <div class="trip-card" data-trip-id="${trip._id || trip.id}">
                    <div class="trip-header" style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 12px;">
                        <div>
                            <div style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 4px;">
                                ${this.formatDate(trip.departureTime)}
                            </div>
                            <div style="font-weight: 600; font-size: 1.1rem;">
                                ${departureTime}
                            </div>
                        </div>
                        <span class="badge ${trip.status === 'ACTIVE' ? 'badge-success' : 'badge-info'}">
                            ${tripStatus}
                        </span>
                    </div>

                    <div class="trip-route" style="margin-bottom: 16px; padding: 12px; background: var(--hover-bg); border-radius: 6px;">
                        <div style="display: flex; align-items: center; justify-content: space-between;">
                            <div>
                                <div style="font-size: 0.75rem; color: var(--text-muted);">DEPARTURE</div>
                                <div style="font-weight: 500;">${this.escapeHtml(this.currentRoute?.startLocation || 'Start')}</div>
                            </div>
                            <div style="flex-shrink: 0; padding: 0 16px; color: var(--primary);">→</div>
                            <div style="text-align: right;">
                                <div style="font-size: 0.75rem; color: var(--text-muted);">ARRIVAL</div>
                                <div style="font-weight: 500;">${this.escapeHtml(this.currentRoute?.endLocation || 'End')}</div>
                            </div>
                        </div>
                        <div style="margin-top: 8px; font-size: 0.85rem; color: var(--text-muted); text-align: center;">
                            Expected arrival: ${arrivalTime}
                        </div>
                    </div>

                    <div class="trip-seats" style="margin-bottom: 16px;">
                        <span class="badge ${seatsBadge}" style="width: 100%; display: block; text-align: center;">
                            ${seatsText}
                        </span>
                    </div>

                    <div class="trip-price" style="font-size: 1.3rem; font-weight: 700; color: var(--primary); text-align: center; margin-bottom: 16px;">
                        N$${(this.currentRoute?.basePrice || 0).toFixed(2)}
                    </div>

                    <button class="btn ${isAvailable ? 'btn-primary' : 'btn-secondary'} purchase-trip-btn" 
                            data-trip-id="${trip._id || trip.id}" 
                            ${!isAvailable ? 'disabled' : ''}
                            style="width: 100%;">
                        ${isAvailable ? '🎫 Purchase Ticket' : '❌ Fully Booked'}
                    </button>
                </div>
            `;
        },

        /**
         * Attach listeners to purchase buttons
         */
        attachPurchaseListeners() {
            const buttons = document.querySelectorAll('.purchase-trip-btn');
            console.log(`🎟️ Attaching listeners to ${buttons.length} purchase buttons`);
            buttons.forEach(btn => {
                const tripId = btn.dataset.tripId;
                console.log('Button trip ID:', tripId);
                btn.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    if (tripId && tripId !== 'undefined') {
                        await this.handlePurchase(tripId);
                    } else {
                        console.error('Invalid trip ID:', tripId);
                        alert('❌ Error: Trip ID is missing. Please refresh the page.');
                    }
                });
            });
        },

        /**
         * Handle ticket purchase
         */
        async handlePurchase(tripId) {
            try {
                // Check if user is logged in
                const api = App.api || window.APIModule;
                if (!api.session.loggedIn) {
                    alert('Please log in to purchase tickets');
                    // Open login modal
                    const loginBtn = document.getElementById('loginBtn');
                    if (loginBtn) loginBtn.click();
                    return;
                }

                // Show purchase confirmation or open ticket purchase flow
                const quantity = 1; // Default quantity
                const paymentMethod = 'CARD'; // Default payment method

                // Show loading on button
                const btn = document.querySelector(`[data-trip-id="${tripId}"]`);
                if (btn) {
                    btn.disabled = true;
                    btn.innerHTML = '⏳ Processing...';
                }

                // Purchase ticket
                const result = await api.purchaseTicket({
                    tripId,
                    quantity,
                    paymentMethod
                });

                if (result.success) {
                    alert('✅ Ticket purchased successfully!');
                    
                    // Close modal
                    this.closeRouteTripsModal();

                    // Refresh passenger view if exists
                    if (typeof testFetchTickets === 'function') {
                        setTimeout(() => testFetchTickets(), 500);
                    }
                } else {
                    throw new Error(result.message || 'Purchase failed');
                }
            } catch (error) {
                console.error('Purchase error:', error);
                alert(`❌ Purchase failed: ${error.message}`);

                // Reset button
                const btn = document.querySelector(`[data-trip-id="${tripId}"]`);
                if (btn) {
                    btn.disabled = false;
                    btn.innerHTML = '🎫 Purchase Ticket';
                }
            }
        },

        /**
         * Format date
         */
        formatDate(dateString) {
            if (!dateString) return 'N/A';
            const date = new Date(dateString);
            return date.toLocaleDateString('en-NA', { 
                weekday: 'short', 
                year: 'numeric', 
                month: 'short', 
                day: 'numeric' 
            });
        },

        /**
         * Format time
         */
        formatTime(dateString) {
            if (!dateString) return 'N/A';
            const date = new Date(dateString);
            return date.toLocaleTimeString('en-NA', { 
                hour: '2-digit', 
                minute: '2-digit'
            });
        },

        /**
         * Format date and time
         */
        formatDateTime(dateString) {
            if (!dateString) return 'N/A';
            return `${this.formatTime(dateString)}`;
        },

        /**
         * Escape HTML to prevent XSS
         */
        escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
    };

    // Export to App namespace
    App.routeBrowser = RouteBrowser;

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => RouteBrowser.init());
    } else {
        RouteBrowser.init();
    }
})();
