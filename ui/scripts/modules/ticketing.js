/**
 * Ticketing Service Module
 * Handles ticketing API testing and display functionality
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
     * Fetch all tickets for logged-in passenger
     */
    async function testFetchTickets() {
        showLoading('ticketsResult');

        try {
            const api = App.api || window.APIModule;
            
            if (!api.session.loggedIn) {
                showError('ticketsResult', 'Please log in to view your tickets.');
                return;
            }

            const tickets = await api.fetchTickets();
            
            if (tickets.length === 0) {
                showEmpty('ticketsResult', 'You have no tickets yet. Purchase a ticket to get started!');
                return;
            }

            let html = `<div class="results"><h3>Found ${tickets.length} Ticket${tickets.length !== 1 ? 's' : ''}</h3>`;
            tickets.slice(0, 10).forEach(ticket => {
                const purchaseDate = new Date(ticket.purchaseDate || ticket.createdAt).toLocaleString();
                const status = ticket.status || 'ACTIVE';
                const statusBadge = status === 'ACTIVE' ? 'badge-success' : 
                                   status === 'USED' ? 'badge-info' : 
                                   status === 'CANCELLED' ? 'badge-warning' : 'badge-info';
                
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Ticket ${ticket._id || ticket.id || ticket.ticketId}</strong>
                            <span class="badge ${statusBadge}">${status}</span>
                        </div>
                        <div class="result-details">
                            <small>Trip: ${ticket.tripId || 'N/A'}</small><br>
                            <small>Purchased: ${purchaseDate}</small><br>
                            <small>Quantity: ${ticket.quantity || 1} | Payment: ${ticket.paymentMethod || 'N/A'}</small>
                        </div>
                    </div>
                `;
            });
            if (tickets.length > 10) {
                html += `<p class="subtle" style="margin-top: 12px;">...and ${tickets.length - 10} more</p>`;
            }
            html += '</div>';
            document.getElementById('ticketsResult').innerHTML = html;
        } catch (error) {
            showError('ticketsResult', `Error: ${error.message}`);
        }
    }

    /**
     * Purchase a new ticket (simulation)
     */
    async function testPurchaseTicket() {
        showLoading('purchaseResult');

        const tripId = document.getElementById('purchaseTripId')?.value || '';
        const quantity = parseInt(document.getElementById('purchaseQuantity')?.value) || 1;
        const paymentMethod = document.getElementById('purchasePaymentMethod')?.value || 'CARD';

        if (!tripId) {
            showError('purchaseResult', 'Please enter a trip ID');
            return;
        }

        try {
            const api = App.api || window.APIModule;
            
            if (!api.session.loggedIn) {
                showError('purchaseResult', 'Please log in to purchase tickets.');
                return;
            }

            const result = await api.purchaseTicket({
                tripId,
                quantity,
                paymentMethod
            });

            if (result.success) {
                let html = `<div class="results">`;
                html += `<div class="success-message" style="padding: 12px; background: var(--success-bg); color: var(--success-text); border: 1px solid var(--success-border); border-radius: var(--radius); margin-bottom: 12px;">
                    ✅ Ticket purchased successfully!
                </div>`;
                html += `<h3>Purchase Details</h3>`;
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Ticket ID: ${result.ticket?.ticketId || result.ticket?._id || 'Generated'}</strong>
                            <span class="badge badge-success">ACTIVE</span>
                        </div>
                        <div class="result-details">
                            <small>Trip: ${tripId}</small><br>
                            <small>Quantity: ${quantity}</small><br>
                            <small>Payment: ${paymentMethod}</small>
                        </div>
                    </div>
                `;
                html += '</div>';
                document.getElementById('purchaseResult').innerHTML = html;

                // Refresh tickets list if visible
                const ticketsResult = document.getElementById('ticketsResult');
                if (ticketsResult && ticketsResult.innerHTML) {
                    setTimeout(() => testFetchTickets(), 1000);
                }
            } else {
                showError('purchaseResult', result.message || 'Purchase failed. Please try again.');
            }
        } catch (error) {
            showError('purchaseResult', `Error: ${error.message}`);
        }
    }

    /**
     * Validate a ticket
     */
    async function testValidateTicket() {
        showLoading('validateResult');

        const ticketId = document.getElementById('validateTicketId')?.value || '';

        if (!ticketId) {
            showError('validateResult', 'Please enter a ticket ID');
            return;
        }

        try {
            const api = App.api || window.APIModule;
            
            // Call validation endpoint
            const result = await api.apiRequest('ticketing', '/api/v1/ticketing/validate', {
                method: 'POST',
                body: JSON.stringify({ ticketId })
            });

            let html = `<div class="results">`;
            
            if (result.valid) {
                html += `<div class="success-message" style="padding: 12px; background: var(--success-bg); color: var(--success-text); border: 1px solid var(--success-border); border-radius: var(--radius); margin-bottom: 12px;">
                    ✅ Ticket is VALID
                </div>`;
            } else {
                html += `<div class="error-message" style="margin-bottom: 12px;">
                    ❌ Ticket is INVALID
                </div>`;
            }

            html += `<h3>Validation Details</h3>`;
            html += `
                <div class="result-item">
                    <div class="result-header">
                        <strong>Ticket ID: ${ticketId}</strong>
                        <span class="badge ${result.valid ? 'badge-success' : 'badge-warning'}">
                            ${result.valid ? 'VALID' : 'INVALID'}
                        </span>
                    </div>
                    <div class="result-details">
                        <small>Status: ${result.status || 'Unknown'}</small><br>
                        ${result.reason ? `<small>Reason: ${result.reason}</small><br>` : ''}
                        <small>Checked: ${new Date().toLocaleString()}</small>
                    </div>
                </div>
            `;
            html += '</div>';
            document.getElementById('validateResult').innerHTML = html;
        } catch (error) {
            showError('validateResult', `Error: ${error.message}`);
        }
    }

    /**
     * Get ticket statistics
     */
    async function testTicketStats() {
        showLoading('statsResult');

        try {
            const api = App.api || window.APIModule;
            
            if (!api.session.loggedIn) {
                showError('statsResult', 'Please log in to view statistics.');
                return;
            }

            const tickets = await api.fetchTickets();
            
            // Calculate statistics
            const stats = {
                total: tickets.length,
                active: tickets.filter(t => (t.status || 'ACTIVE') === 'ACTIVE').length,
                used: tickets.filter(t => (t.status || '') === 'USED').length,
                cancelled: tickets.filter(t => (t.status || '') === 'CANCELLED').length,
                totalAmount: tickets.reduce((sum, t) => sum + (t.amount || 0), 0),
                totalQuantity: tickets.reduce((sum, t) => sum + (t.quantity || 1), 0)
            };

            let html = `<div class="results">`;
            html += `<h3>Your Ticket Statistics</h3>`;
            html += `
                <div class="stats-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; margin-top: 12px;">
                    <div class="stat-card" style="padding: 12px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); text-align: center;">
                        <div style="font-size: 1.8rem; font-weight: bold; color: var(--primary);">${stats.total}</div>
                        <div style="font-size: 0.85rem; color: var(--muted); margin-top: 4px;">Total Tickets</div>
                    </div>
                    <div class="stat-card" style="padding: 12px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); text-align: center;">
                        <div style="font-size: 1.8rem; font-weight: bold; color: var(--success-text);">${stats.active}</div>
                        <div style="font-size: 0.85rem; color: var(--muted); margin-top: 4px;">Active</div>
                    </div>
                    <div class="stat-card" style="padding: 12px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); text-align: center;">
                        <div style="font-size: 1.8rem; font-weight: bold; color: var(--info-text);">${stats.used}</div>
                        <div style="font-size: 0.85rem; color: var(--muted); margin-top: 4px;">Used</div>
                    </div>
                    <div class="stat-card" style="padding: 12px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); text-align: center;">
                        <div style="font-size: 1.8rem; font-weight: bold; color: var(--warning-text);">${stats.cancelled}</div>
                        <div style="font-size: 0.85rem; color: var(--muted); margin-top: 4px;">Cancelled</div>
                    </div>
                    <div class="stat-card" style="padding: 12px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); text-align: center;">
                        <div style="font-size: 1.8rem; font-weight: bold; color: var(--primary);">${stats.totalQuantity}</div>
                        <div style="font-size: 0.85rem; color: var(--muted); margin-top: 4px;">Total Seats</div>
                    </div>
                    <div class="stat-card" style="padding: 12px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); text-align: center;">
                        <div style="font-size: 1.8rem; font-weight: bold; color: var(--green);">N$${stats.totalAmount.toFixed(2)}</div>
                        <div style="font-size: 0.85rem; color: var(--muted); margin-top: 4px;">Total Spent</div>
                    </div>
                </div>
            `;
            html += '</div>';
            document.getElementById('statsResult').innerHTML = html;
        } catch (error) {
            showError('statsResult', `Error: ${error.message}`);
        }
    }

    /**
     * Search tickets by criteria
     */
    async function testSearchTickets() {
        showLoading('searchTicketsResult');

        const status = document.getElementById('searchTicketStatus')?.value || '';
        const tripId = document.getElementById('searchTicketTripId')?.value || '';

        try {
            const api = App.api || window.APIModule;
            
            if (!api.session.loggedIn) {
                showError('searchTicketsResult', 'Please log in to search tickets.');
                return;
            }

            const allTickets = await api.fetchTickets();
            
            // Filter tickets
            let tickets = allTickets;
            if (status) {
                tickets = tickets.filter(t => (t.status || 'ACTIVE') === status);
            }
            if (tripId) {
                tickets = tickets.filter(t => String(t.tripId).includes(tripId));
            }

            if (tickets.length === 0) {
                showEmpty('searchTicketsResult', 'No tickets match your search criteria.');
                return;
            }

            let html = `<div class="results"><h3>Found ${tickets.length} Ticket${tickets.length !== 1 ? 's' : ''}</h3>`;
            tickets.forEach(ticket => {
                const purchaseDate = new Date(ticket.purchaseDate || ticket.createdAt).toLocaleString();
                const ticketStatus = ticket.status || 'ACTIVE';
                const statusBadge = ticketStatus === 'ACTIVE' ? 'badge-success' : 
                                   ticketStatus === 'USED' ? 'badge-info' : 
                                   ticketStatus === 'CANCELLED' ? 'badge-warning' : 'badge-info';
                
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Ticket ${ticket._id || ticket.id || ticket.ticketId}</strong>
                            <span class="badge ${statusBadge}">${ticketStatus}</span>
                        </div>
                        <div class="result-details">
                            <small>Trip: ${ticket.tripId || 'N/A'}</small><br>
                            <small>Purchased: ${purchaseDate}</small><br>
                            <small>Quantity: ${ticket.quantity || 1}</small>
                        </div>
                    </div>
                `;
            });
            html += '</div>';
            document.getElementById('searchTicketsResult').innerHTML = html;
        } catch (error) {
            showError('searchTicketsResult', `Error: ${error.message}`);
        }
    }

    /**
     * Get recent ticket purchases
     */
    async function testRecentPurchases() {
        showLoading('recentResult');

        const limit = parseInt(document.getElementById('recentLimit')?.value) || 5;

        try {
            const api = App.api || window.APIModule;
            
            if (!api.session.loggedIn) {
                showError('recentResult', 'Please log in to view recent purchases.');
                return;
            }

            const tickets = await api.fetchTickets();
            
            // Sort by purchase date (newest first) and limit
            const recentTickets = tickets
                .sort((a, b) => {
                    const dateA = new Date(a.purchaseDate || a.createdAt || 0);
                    const dateB = new Date(b.purchaseDate || b.createdAt || 0);
                    return dateB - dateA;
                })
                .slice(0, limit);

            if (recentTickets.length === 0) {
                showEmpty('recentResult', 'No recent purchases found.');
                return;
            }

            let html = `<div class="results"><h3>${recentTickets.length} Recent Purchase${recentTickets.length !== 1 ? 's' : ''}</h3>`;
            recentTickets.forEach((ticket, index) => {
                const purchaseDate = new Date(ticket.purchaseDate || ticket.createdAt);
                const timeAgo = getTimeAgo(purchaseDate);
                const statusBadge = (ticket.status || 'ACTIVE') === 'ACTIVE' ? 'badge-success' : 'badge-info';
                
                html += `
                    <div class="result-item">
                        <div class="result-header">
                            <strong>#${index + 1}: ${purchaseDate.toLocaleDateString()}</strong>
                            <span class="badge ${statusBadge}">${timeAgo}</span>
                        </div>
                        <div class="result-details">
                            <small>Ticket: ${ticket._id || ticket.id || ticket.ticketId}</small><br>
                            <small>Trip: ${ticket.tripId || 'N/A'}</small><br>
                            <small>Quantity: ${ticket.quantity || 1} | ${ticket.paymentMethod || 'N/A'}</small>
                        </div>
                    </div>
                `;
            });
            html += '</div>';
            document.getElementById('recentResult').innerHTML = html;
        } catch (error) {
            showError('recentResult', `Error: ${error.message}`);
        }
    }

    /**
     * Helper function to calculate time ago
     */
    function getTimeAgo(date) {
        const seconds = Math.floor((new Date() - date) / 1000);
        
        const intervals = {
            year: 31536000,
            month: 2592000,
            week: 604800,
            day: 86400,
            hour: 3600,
            minute: 60
        };
        
        for (const [unit, secondsInUnit] of Object.entries(intervals)) {
            const interval = Math.floor(seconds / secondsInUnit);
            if (interval >= 1) {
                return `${interval} ${unit}${interval !== 1 ? 's' : ''} ago`;
            }
        }
        
        return 'Just now';
    }

    /**
     * Initialize ticketing service view
     */
    async function initTicketingView() {
        console.log('Ticketing Service view initializing...');
        
        const api = App.api || window.APIModule;
        
        // Check if user is logged in
        if (!api.session.loggedIn) {
            const containers = ['ticketsResult', 'purchaseResult', 'validateResult', 'statsResult', 'searchTicketsResult', 'recentResult'];
            containers.forEach(id => {
                const container = document.getElementById(id);
                if (container) {
                    container.innerHTML = '';
                }
            });
        } else {
            // Auto-populate trip ID from first available trip
            try {
                const trips = await api.fetchTrips();
                if (trips.length > 0) {
                    const tripIdInput = document.getElementById('purchaseTripId');
                    if (tripIdInput && !tripIdInput.value) {
                        tripIdInput.value = trips[0]._id || trips[0].id;
                    }
                }
            } catch (error) {
                console.error('Failed to pre-load trip ID:', error);
            }
        }

        console.log('Ticketing Service view ready!');
    }

    // Expose public API
    App.ticketing = {
        testFetchTickets,
        testPurchaseTicket,
        testValidateTicket,
        testTicketStats,
        testSearchTickets,
        testRecentPurchases,
        initTicketingView
    };

    // Make functions available globally for onclick handlers
    window.testFetchTickets = testFetchTickets;
    window.testPurchaseTicket = testPurchaseTicket;
    window.testValidateTicket = testValidateTicket;
    window.testTicketStats = testTicketStats;
    window.testSearchTickets = testSearchTickets;
    window.testRecentPurchases = testRecentPurchases;

    console.log('Ticketing module loaded');
})();
