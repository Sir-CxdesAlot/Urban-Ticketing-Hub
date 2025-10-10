/**
 * Search Module - Comprehensive Search Functionality
 * Provides real-time search for routes, trips, tickets, and schedules
 */

(function() {
  'use strict';

  // Search configuration
  const SEARCH_CONFIG = {
    minQueryLength: 2,
    debounceDelay: 300, // ms
    maxResults: 10,
    highlightClass: 'search-highlight'
  };

  // Search categories
  const SEARCH_CATEGORIES = {
    ROUTES: {
      name: 'Routes',
      icon: '🚍',
      searchFunction: searchRoutes,
      resultTemplate: formatRouteResult,
      permission: 'VIEW_PUBLIC_ROUTES'
    },
    TRIPS: {
      name: 'Trips',
      icon: '🚌',
      searchFunction: searchTrips,
      resultTemplate: formatTripResult,
      permission: 'VIEW_PUBLIC_ROUTES'
    },
    TICKETS: {
      name: 'Tickets',
      icon: '🎫',
      searchFunction: searchTickets,
      resultTemplate: formatTicketResult,
      permission: 'PURCHASE_TICKETS'
    },
    SCHEDULES: {
      name: 'Schedules',
      icon: '📅',
      searchFunction: searchSchedules,
      resultTemplate: formatScheduleResult,
      permission: 'VIEW_PUBLIC_ROUTES'
    }
  };

  // DOM elements
  let searchInput;
  let searchClear;
  let searchResults;
  let searchDebounceTimer;

  /**
   * Initialize search module
   */
  function init() {
    searchInput = document.getElementById('search');
    searchClear = document.getElementById('searchClear');
    searchResults = document.getElementById('searchResults');

    if (!searchInput || !searchClear || !searchResults) {
      console.warn('Search elements not found in DOM');
      return;
    }

    attachEventListeners();
    console.log('✅ Search module initialized');
  }

  /**
   * Attach event listeners
   */
  function attachEventListeners() {
    // Search input
    searchInput.addEventListener('input', handleSearchInput);
    searchInput.addEventListener('focus', handleSearchFocus);
    searchInput.addEventListener('keydown', handleSearchKeydown);

    // Clear button
    searchClear.addEventListener('click', handleClearClick);

    // Close results when clicking outside
    document.addEventListener('click', handleOutsideClick);

    // Escape key to close results
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        hideResults();
      }
    });
  }

  /**
   * Handle search input
   */
  function handleSearchInput(e) {
    const query = e.target.value.trim();

    // Clear debounce timer
    clearTimeout(searchDebounceTimer);

    // Show/hide clear button
    if (query) {
      searchClear.style.display = 'block';
    } else {
      searchClear.style.display = 'none';
      hideResults();
      return;
    }

    // Check minimum query length
    if (query.length < SEARCH_CONFIG.minQueryLength) {
      showHint(`Type at least ${SEARCH_CONFIG.minQueryLength} characters to search...`);
      return;
    }

    // Debounce search
    searchDebounceTimer = setTimeout(() => {
      performSearch(query);
    }, SEARCH_CONFIG.debounceDelay);
  }

  /**
   * Handle search focus
   */
  function handleSearchFocus() {
    const query = searchInput.value.trim();
    if (query && query.length >= SEARCH_CONFIG.minQueryLength) {
      searchResults.removeAttribute('hidden');
    }
  }

  /**
   * Handle search keydown (navigation)
   */
  function handleSearchKeydown(e) {
    const items = searchResults.querySelectorAll('.search-result-item');
    const activeItem = searchResults.querySelector('.search-result-item.active');
    
    if (items.length === 0) return;

    let currentIndex = -1;
    if (activeItem) {
      currentIndex = Array.from(items).indexOf(activeItem);
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        if (currentIndex < items.length - 1) {
          if (activeItem) activeItem.classList.remove('active');
          items[currentIndex + 1].classList.add('active');
          items[currentIndex + 1].scrollIntoView({ block: 'nearest' });
        }
        break;

      case 'ArrowUp':
        e.preventDefault();
        if (currentIndex > 0) {
          if (activeItem) activeItem.classList.remove('active');
          items[currentIndex - 1].classList.add('active');
          items[currentIndex - 1].scrollIntoView({ block: 'nearest' });
        }
        break;

      case 'Enter':
        e.preventDefault();
        if (activeItem) {
          activeItem.click();
        } else if (items.length > 0) {
          items[0].click();
        }
        break;
    }
  }

  /**
   * Handle clear button click
   */
  function handleClearClick() {
    searchInput.value = '';
    searchClear.style.display = 'none';
    hideResults();
    searchInput.focus();

    // Log clear action
    if (window.SecurityModule) {
      window.SecurityModule.createAuditLog('SEARCH_CLEARED', {
        action: 'Search cleared by user'
      });
    }
  }

  /**
   * Handle click outside search
   */
  function handleOutsideClick(e) {
    if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
      hideResults();
    }
  }

  /**
   * Perform comprehensive search
   */
  async function performSearch(query) {
    showLoading();

    const api = window.APIModule || window.App?.api;
    if (!api) {
      showError('API module not loaded');
      return;
    }

    try {
      const results = {
        routes: [],
        trips: [],
        tickets: [],
        schedules: []
      };

      // Search all categories in parallel
      const searchPromises = [];

      // Check permissions before searching
      const hasPermission = (permission) => {
        return api.hasPermission && api.hasPermission(permission);
      };

      // Search routes
      if (hasPermission('VIEW_PUBLIC_ROUTES')) {
        searchPromises.push(
          searchRoutes(query, api).then(data => { results.routes = data; })
        );
      }

      // Search trips
      if (hasPermission('VIEW_PUBLIC_ROUTES')) {
        searchPromises.push(
          searchTrips(query, api).then(data => { results.trips = data; })
        );
      }

      // Search tickets (only for logged-in users)
      if (hasPermission('PURCHASE_TICKETS') && api.session?.loggedIn) {
        searchPromises.push(
          searchTickets(query, api).then(data => { results.tickets = data; })
        );
      }

      // Search schedules
      if (hasPermission('VIEW_PUBLIC_ROUTES')) {
        searchPromises.push(
          searchSchedules(query, api).then(data => { results.schedules = data; })
        );
      }

      // Wait for all searches to complete
      await Promise.all(searchPromises);

      // Display results
      displayResults(results, query);

      // Log search
      if (window.SecurityModule) {
        window.SecurityModule.createAuditLog('SEARCH_PERFORMED', {
          query: query,
          resultsFound: Object.values(results).reduce((sum, arr) => sum + arr.length, 0)
        });
      }

    } catch (error) {
      console.error('Search error:', error);
      showError('An error occurred while searching. Please try again.');
    }
  }

  /**
   * Search routes
   */
  async function searchRoutes(query, api) {
    try {
      const routes = await api.searchRoutes({
        query: query
      });

      if (!routes || !routes.data) return [];

      return routes.data
        .slice(0, SEARCH_CONFIG.maxResults)
        .map(route => ({
          ...route,
          category: 'routes',
          type: 'route'
        }));
    } catch (error) {
      console.error('Route search error:', error);
      return [];
    }
  }

  /**
   * Search trips
   */
  async function searchTrips(query, api) {
    try {
      const trips = await api.searchTrips({
        query: query
      });

      if (!trips || !trips.data) return [];

      return trips.data
        .slice(0, SEARCH_CONFIG.maxResults)
        .map(trip => ({
          ...trip,
          category: 'trips',
          type: 'trip'
        }));
    } catch (error) {
      console.error('Trip search error:', error);
      return [];
    }
  }

  /**
   * Search tickets
   */
  async function searchTickets(query, api) {
    try {
      // Get user tickets (returns array directly)
      const tickets = await api.fetchTickets();

      if (!tickets || !Array.isArray(tickets)) return [];

      // Filter tickets by query
      const filtered = tickets.filter(ticket => {
        const searchString = `${ticket.ticketNumber} ${ticket.status} ${ticket.tripId}`.toLowerCase();
        return searchString.includes(query.toLowerCase());
      });

      return filtered
        .slice(0, SEARCH_CONFIG.maxResults)
        .map(ticket => ({
          ...ticket,
          category: 'tickets',
          type: 'ticket'
        }));
    } catch (error) {
      console.error('Ticket search error:', error);
      return [];
    }
  }

  /**
   * Search schedules
   */
  async function searchSchedules(query, api) {
    try {
      // Get all trips using searchTrips (no criteria = all trips)
      const trips = await api.searchTrips({});

      if (!trips || !Array.isArray(trips)) return [];

      // Filter trips by schedule-related fields
      const filtered = trips.filter(trip => {
        const scheduleString = `${trip.departureTime} ${trip.arrivalTime} ${trip.routeId}`.toLowerCase();
        return scheduleString.includes(query.toLowerCase());
      });

      return filtered
        .slice(0, SEARCH_CONFIG.maxResults)
        .map(trip => ({
          ...trip,
          category: 'schedules',
          type: 'schedule'
        }));
    } catch (error) {
      console.error('Schedule search error:', error);
      return [];
    }
  }

  /**
   * Display search results
   */
  function displayResults(results, query) {
    const totalResults = Object.values(results).reduce((sum, arr) => sum + arr.length, 0);

    if (totalResults === 0) {
      showNoResults(query);
      return;
    }

    let html = `<div class="search-results-header">
      <span class="search-results-count">Found ${totalResults} result${totalResults !== 1 ? 's' : ''}</span>
    </div>`;

    // Display routes
    if (results.routes.length > 0) {
      html += createCategorySection('Routes', results.routes, formatRouteResult, query);
    }

    // Display trips
    if (results.trips.length > 0) {
      html += createCategorySection('Trips', results.trips, formatTripResult, query);
    }

    // Display tickets
    if (results.tickets.length > 0) {
      html += createCategorySection('Tickets', results.tickets, formatTicketResult, query);
    }

    // Display schedules
    if (results.schedules.length > 0) {
      html += createCategorySection('Schedules', results.schedules, formatScheduleResult, query);
    }

    searchResults.innerHTML = html;
    searchResults.removeAttribute('hidden');
  }

  /**
   * Create category section
   */
  function createCategorySection(title, items, formatter, query) {
    let html = `<div class="search-category">
      <div class="search-category-title">${title}</div>
      <div class="search-category-items">`;

    items.forEach(item => {
      html += formatter(item, query);
    });

    html += `</div></div>`;
    return html;
  }

  /**
   * Format route result
   */
  function formatRouteResult(route, query) {
    const highlightedName = highlightMatch(route.name || 'Unknown Route', query);
    const highlightedRoute = highlightMatch(`${route.origin} → ${route.destination}`, query);

    return `
      <div class="search-result-item" data-type="route" data-id="${route.routeId || route.id}" role="option">
        <div class="search-result-icon">🚍</div>
        <div class="search-result-content">
          <div class="search-result-title">${highlightedName}</div>
          <div class="search-result-subtitle">${highlightedRoute}</div>
          <div class="search-result-meta">
            <span class="badge ${route.type === 'express' ? 'badge-primary' : 'badge-secondary'}">${route.type || 'Standard'}</span>
            <span class="search-result-distance">${route.distance || 'N/A'} km</span>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Format trip result
   */
  function formatTripResult(trip, query) {
    const highlightedRoute = highlightMatch(trip.routeId || 'Unknown Route', query);
    const departureTime = formatTime(trip.departureTime);
    const arrivalTime = formatTime(trip.arrivalTime);

    return `
      <div class="search-result-item" data-type="trip" data-id="${trip.tripId || trip.id}" role="option">
        <div class="search-result-icon">🚌</div>
        <div class="search-result-content">
          <div class="search-result-title">Trip ${highlightedRoute}</div>
          <div class="search-result-subtitle">${departureTime} - ${arrivalTime}</div>
          <div class="search-result-meta">
            <span class="badge ${trip.status === 'active' ? 'badge-success' : 'badge-secondary'}">${trip.status || 'Scheduled'}</span>
            <span class="search-result-price">N$${trip.price || trip.fare || 'N/A'}</span>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Format ticket result
   */
  function formatTicketResult(ticket, query) {
    const highlightedNumber = highlightMatch(ticket.ticketNumber || 'Unknown', query);
    const statusClass = ticket.status === 'active' ? 'badge-success' : 
                        ticket.status === 'used' ? 'badge-secondary' : 
                        ticket.status === 'expired' ? 'badge-danger' : 'badge-warning';

    return `
      <div class="search-result-item" data-type="ticket" data-id="${ticket.ticketId || ticket.id}" role="option">
        <div class="search-result-icon">🎫</div>
        <div class="search-result-content">
          <div class="search-result-title">Ticket ${highlightedNumber}</div>
          <div class="search-result-subtitle">Trip: ${ticket.tripId || 'N/A'}</div>
          <div class="search-result-meta">
            <span class="badge ${statusClass}">${ticket.status || 'Unknown'}</span>
            <span class="search-result-date">${formatDate(ticket.purchaseDate)}</span>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Format schedule result
   */
  function formatScheduleResult(schedule, query) {
    const departureTime = formatTime(schedule.departureTime);
    const arrivalTime = formatTime(schedule.arrivalTime);
    const highlightedRoute = highlightMatch(schedule.routeId || 'Unknown Route', query);

    return `
      <div class="search-result-item" data-type="schedule" data-id="${schedule.tripId || schedule.id}" role="option">
        <div class="search-result-icon">📅</div>
        <div class="search-result-content">
          <div class="search-result-title">${highlightedRoute}</div>
          <div class="search-result-subtitle">${departureTime} - ${arrivalTime}</div>
          <div class="search-result-meta">
            <span class="search-result-frequency">${schedule.frequency || 'Daily'}</span>
            <span class="search-result-duration">${schedule.duration || 'N/A'} min</span>
          </div>
        </div>
      </div>
    `;
  }

  /**
   * Highlight matching text
   */
  function highlightMatch(text, query) {
    if (!text || !query) return text;

    const regex = new RegExp(`(${escapeRegex(query)})`, 'gi');
    return text.replace(regex, '<mark class="' + SEARCH_CONFIG.highlightClass + '">$1</mark>');
  }

  /**
   * Escape regex special characters
   */
  function escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * Format time
   */
  function formatTime(time) {
    if (!time) return 'N/A';
    if (time instanceof Date) {
      return time.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
    }
    return time;
  }

  /**
   * Format date
   */
  function formatDate(date) {
    if (!date) return 'N/A';
    if (date instanceof Date) {
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
    return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  /**
   * Show loading state
   */
  function showLoading() {
    searchResults.innerHTML = `
      <div class="search-loading">
        <div class="loading-spinner"></div>
        <div class="loading-text">Searching...</div>
      </div>
    `;
    searchResults.removeAttribute('hidden');
  }

  /**
   * Show hint
   */
  function showHint(message) {
    searchResults.innerHTML = `
      <div class="search-hint">
        <div class="search-hint-icon">💡</div>
        <div class="search-hint-text">${message}</div>
      </div>
    `;
    searchResults.removeAttribute('hidden');
  }

  /**
   * Show no results
   */
  function showNoResults(query) {
    searchResults.innerHTML = `
      <div class="search-empty">
        <div class="search-empty-icon">🔍</div>
        <div class="search-empty-title">No results found</div>
        <div class="search-empty-subtitle">Try different keywords for "${query}"</div>
        <div class="search-empty-suggestions">
          <strong>Suggestions:</strong>
          <ul>
            <li>Check your spelling</li>
            <li>Try more general keywords</li>
            <li>Try different keywords</li>
          </ul>
        </div>
      </div>
    `;
    searchResults.removeAttribute('hidden');
  }

  /**
   * Show error
   */
  function showError(message) {
    searchResults.innerHTML = `
      <div class="search-error">
        <div class="search-error-icon">⚠️</div>
        <div class="search-error-text">${message}</div>
      </div>
    `;
    searchResults.removeAttribute('hidden');
  }

  /**
   * Hide results
   */
  function hideResults() {
    searchResults.setAttribute('hidden', '');
    searchResults.innerHTML = '';
  }

  /**
   * Clear search
   */
  function clear() {
    searchInput.value = '';
    searchClear.style.display = 'none';
    hideResults();
  }

  /**
   * Focus search input
   */
  function focus() {
    searchInput.focus();
  }

  // Initialize when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // Export module
  const SearchModule = {
    init,
    clear,
    focus,
    performSearch,
    SEARCH_CONFIG,
    SEARCH_CATEGORIES
  };

  window.SearchModule = SearchModule;
  if (!window.App) window.App = {};
  window.App.search = SearchModule;

  console.log('🔍 Search module loaded');

})();
