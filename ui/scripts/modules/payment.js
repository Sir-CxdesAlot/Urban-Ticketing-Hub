/**
 * Payment Service Module
 * Handles payment processing, transaction history, refunds, and payment methods
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});
    const CONFIG = {
        baseUrl: 'http://localhost:8084',
        endpoints: {
            process: '/api/v1/payment/process',
            history: '/api/v1/payment/history',
            transaction: '/api/v1/payment/transaction',
            refund: '/api/v1/payment/refund',
            methods: '/api/v1/payment/methods',
            statistics: '/api/v1/payment/statistics'
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

    function formatCurrency(amount) {
        return new Intl.NumberFormat('en-NA', {
            style: 'currency',
            currency: 'NAD'
        }).format(amount);
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

    function getStatusBadgeClass(status) {
        const statusMap = {
            'COMPLETED': 'badge-success',
            'SUCCESS': 'badge-success',
            'PENDING': 'badge-warning',
            'PROCESSING': 'badge-warning',
            'FAILED': 'badge-danger',
            'CANCELLED': 'badge-danger',
            'REFUNDED': 'badge-info'
        };
        return statusMap[status] || 'badge-info';
    }

    function getPaymentMethodIcon(method) {
        const icons = {
            'CARD': '💳',
            'CREDIT_CARD': '💳',
            'DEBIT_CARD': '💳',
            'MOBILE': '📱',
            'MOBILE_MONEY': '📱',
            'CASH': '💵',
            'WALLET': '👛',
            'BANK_TRANSFER': '🏦'
        };
        return icons[method] || '💰';
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
        console.log(`Payment API: ${method} ${url}`, data || '');

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
     * Test 1: Process Payment
     * Process a new payment transaction
     */
    async function testProcessPayment() {
        const containerId = 'processResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to process payments');
            return;
        }

        try {
            const ticketId = document.getElementById('processTicketId')?.value?.trim();
            const amount = parseFloat(document.getElementById('processAmount')?.value || '0');
            const method = document.getElementById('processMethod')?.value;

            if (!ticketId) {
                showError(containerId, 'Please enter a ticket ID');
                return;
            }

            if (amount <= 0) {
                showError(containerId, 'Please enter a valid amount');
                return;
            }

            if (!method) {
                showError(containerId, 'Please select a payment method');
                return;
            }

            const paymentData = {
                ticketId,
                amount,
                paymentMethod: method,
                currency: 'NAD'
            };

            const response = await apiRequest(CONFIG.endpoints.process, 'POST', paymentData);
            
            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="success-message">✅ Payment processed successfully!</div>
                <div class="results">
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Transaction ID:</strong> ${response.transactionId || response.id || 'N/A'}
                        </div>
                        <div class="result-details">
                            <div><strong>Amount:</strong> ${formatCurrency(response.amount || amount)}</div>
                            <div><strong>Method:</strong> ${getPaymentMethodIcon(method)} ${method}</div>
                            <div><strong>Status:</strong> <span class="badge ${getStatusBadgeClass(response.status || 'COMPLETED')}">${response.status || 'COMPLETED'}</span></div>
                            <div><strong>Ticket:</strong> ${ticketId}</div>
                            ${response.timestamp ? `<div><strong>Time:</strong> ${formatDate(response.timestamp)}</div>` : ''}
                        </div>
                    </div>
                </div>
            `;

            console.log('Payment processed:', response);
        } catch (error) {
            console.error('Process payment error:', error);
            showError(containerId, error.message || 'Failed to process payment');
        }
    }

    /**
     * Test 2: Payment History
     * Fetch user's payment transaction history
     */
    async function testPaymentHistory() {
        const containerId = 'historyResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view payment history');
            return;
        }

        try {
            const limit = parseInt(document.getElementById('historyLimit')?.value || '10');
            const response = await apiRequest(`${CONFIG.endpoints.history}?limit=${limit}`, 'GET');
            
            const payments = response.payments || response.data || response || [];

            if (!payments.length) {
                showEmpty(containerId, 'No payment history found');
                return;
            }

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    ${payments.map(payment => `
                        <div class="result-item">
                            <div class="result-header">
                                <strong>${getPaymentMethodIcon(payment.paymentMethod)} ${formatCurrency(payment.amount)}</strong>
                                <span class="badge ${getStatusBadgeClass(payment.status)}">${payment.status}</span>
                            </div>
                            <div class="result-details">
                                <div><strong>ID:</strong> ${payment.id || payment.transactionId || 'N/A'}</div>
                                <div><strong>Method:</strong> ${payment.paymentMethod}</div>
                                ${payment.ticketId ? `<div><strong>Ticket:</strong> ${payment.ticketId}</div>` : ''}
                                ${payment.timestamp || payment.createdAt ? `<div><strong>Date:</strong> ${formatDate(payment.timestamp || payment.createdAt)}</div>` : ''}
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;

            console.log('Payment history:', payments);
        } catch (error) {
            console.error('Payment history error:', error);
            showError(containerId, error.message || 'Failed to load payment history');
        }
    }

    /**
     * Test 3: Transaction Details
     * Get detailed information about a specific transaction
     */
    async function testTransactionDetails() {
        const containerId = 'transactionResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view transaction details');
            return;
        }

        try {
            const transactionId = document.getElementById('transactionId')?.value?.trim();

            if (!transactionId) {
                showError(containerId, 'Please enter a transaction ID');
                return;
            }

            const response = await apiRequest(`${CONFIG.endpoints.transaction}/${transactionId}`, 'GET');
            const transaction = response.transaction || response.data || response;

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Transaction Details</strong>
                            <span class="badge ${getStatusBadgeClass(transaction.status)}">${transaction.status}</span>
                        </div>
                        <div class="result-details">
                            <div><strong>ID:</strong> ${transaction.id || transaction.transactionId || transactionId}</div>
                            <div><strong>Amount:</strong> ${formatCurrency(transaction.amount)}</div>
                            <div><strong>Method:</strong> ${getPaymentMethodIcon(transaction.paymentMethod)} ${transaction.paymentMethod}</div>
                            ${transaction.ticketId ? `<div><strong>Ticket ID:</strong> ${transaction.ticketId}</div>` : ''}
                            ${transaction.userId ? `<div><strong>User ID:</strong> ${transaction.userId}</div>` : ''}
                            ${transaction.currency ? `<div><strong>Currency:</strong> ${transaction.currency}</div>` : ''}
                            ${transaction.timestamp || transaction.createdAt ? `<div><strong>Created:</strong> ${formatDate(transaction.timestamp || transaction.createdAt)}</div>` : ''}
                            ${transaction.updatedAt ? `<div><strong>Updated:</strong> ${formatDate(transaction.updatedAt)}</div>` : ''}
                            ${transaction.description ? `<div><strong>Description:</strong> ${transaction.description}</div>` : ''}
                        </div>
                    </div>
                </div>
            `;

            console.log('Transaction details:', transaction);
        } catch (error) {
            console.error('Transaction details error:', error);
            showError(containerId, error.message || 'Failed to load transaction details');
        }
    }

    /**
     * Test 4: Request Refund
     * Request a refund for a payment transaction
     */
    async function testRequestRefund() {
        const containerId = 'refundResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to request refunds');
            return;
        }

        try {
            const transactionId = document.getElementById('refundTransactionId')?.value?.trim();
            const reason = document.getElementById('refundReason')?.value?.trim();

            if (!transactionId) {
                showError(containerId, 'Please enter a transaction ID');
                return;
            }

            const refundData = {
                transactionId,
                reason: reason || 'Customer request'
            };

            const response = await apiRequest(CONFIG.endpoints.refund, 'POST', refundData);
            
            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="success-message">✅ Refund request submitted successfully!</div>
                <div class="results">
                    <div class="result-item">
                        <div class="result-header">
                            <strong>Refund Request</strong>
                            <span class="badge ${getStatusBadgeClass(response.status || 'PENDING')}">${response.status || 'PENDING'}</span>
                        </div>
                        <div class="result-details">
                            <div><strong>Refund ID:</strong> ${response.refundId || response.id || 'N/A'}</div>
                            <div><strong>Transaction ID:</strong> ${transactionId}</div>
                            ${response.amount ? `<div><strong>Amount:</strong> ${formatCurrency(response.amount)}</div>` : ''}
                            <div><strong>Reason:</strong> ${reason || 'Customer request'}</div>
                            ${response.estimatedTime ? `<div><strong>Processing Time:</strong> ${response.estimatedTime}</div>` : '<div><strong>Processing Time:</strong> 3-5 business days</div>'}
                        </div>
                    </div>
                </div>
            `;

            console.log('Refund requested:', response);
        } catch (error) {
            console.error('Refund request error:', error);
            showError(containerId, error.message || 'Failed to request refund');
        }
    }

    /**
     * Test 5: Payment Methods
     * Get available payment methods for the user
     */
    async function testPaymentMethods() {
        const containerId = 'methodsResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view payment methods');
            return;
        }

        try {
            const response = await apiRequest(CONFIG.endpoints.methods, 'GET');
            const methods = response.methods || response.data || response || [];

            if (!methods.length) {
                showEmpty(containerId, 'No payment methods available');
                return;
            }

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="results">
                    ${methods.map(method => `
                        <div class="result-item">
                            <div class="result-header">
                                <strong>${getPaymentMethodIcon(method.type || method.method)} ${method.name || method.type || method.method}</strong>
                                ${method.isDefault ? '<span class="badge badge-info">Default</span>' : ''}
                                ${method.enabled ? '<span class="badge badge-success">Active</span>' : '<span class="badge badge-danger">Inactive</span>'}
                            </div>
                            <div class="result-details">
                                <div><strong>Type:</strong> ${method.type || method.method}</div>
                                ${method.description ? `<div><strong>Description:</strong> ${method.description}</div>` : ''}
                                ${method.fee ? `<div><strong>Fee:</strong> ${method.fee}</div>` : ''}
                                ${method.lastUsed ? `<div><strong>Last Used:</strong> ${formatDate(method.lastUsed)}</div>` : ''}
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;

            console.log('Payment methods:', methods);
        } catch (error) {
            console.error('Payment methods error:', error);
            showError(containerId, error.message || 'Failed to load payment methods');
        }
    }

    /**
     * Test 6: Payment Statistics
     * Get payment statistics and analytics
     */
    async function testPaymentStatistics() {
        const containerId = 'paymentStatsResult';
        showLoading(containerId);

        if (!checkAuthentication()) {
            showError(containerId, 'Please login to view payment statistics');
            return;
        }

        try {
            const response = await apiRequest(CONFIG.endpoints.statistics, 'GET');
            const stats = response.statistics || response.data || response;

            // Calculate statistics from history if not provided
            let totalTransactions = stats.totalTransactions || stats.total || 0;
            let totalAmount = stats.totalAmount || stats.amount || 0;
            let successfulPayments = stats.successfulPayments || stats.successful || 0;
            let failedPayments = stats.failedPayments || stats.failed || 0;
            let averageAmount = stats.averageAmount || (totalTransactions > 0 ? totalAmount / totalTransactions : 0);
            let mostUsedMethod = stats.mostUsedMethod || stats.preferredMethod || 'N/A';

            const container = document.getElementById(containerId);
            container.innerHTML = `
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-value">${totalTransactions}</div>
                        <div class="stat-label">Total Transactions</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${formatCurrency(totalAmount)}</div>
                        <div class="stat-label">Total Amount</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${successfulPayments}</div>
                        <div class="stat-label">Successful Payments</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${failedPayments}</div>
                        <div class="stat-label">Failed Payments</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${formatCurrency(averageAmount)}</div>
                        <div class="stat-label">Average Amount</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-value">${getPaymentMethodIcon(mostUsedMethod)} ${mostUsedMethod}</div>
                        <div class="stat-label">Most Used Method</div>
                    </div>
                </div>
            `;

            console.log('Payment statistics:', stats);
        } catch (error) {
            console.error('Payment statistics error:', error);
            showError(containerId, error.message || 'Failed to load payment statistics');
        }
    }

    /**
     * Initialize Payment View
     * Set up the payment view with default values and clear containers
     */
    async function initPaymentView() {
        console.log('Initializing Payment Service view...');
        
        // Check authentication
        if (!checkAuthentication()) {
            const containers = [
                'processResult', 'historyResult', 'transactionResult',
                'refundResult', 'methodsResult', 'paymentStatsResult'
            ];
            containers.forEach(id => {
                const container = document.getElementById(id);
                if (container) {
                    container.innerHTML = '<div class="info-message">ℹ️ Please login to access payment features</div>';
                }
            });
            return;
        }

        // Clear all result containers
        const containers = [
            'processResult', 'historyResult', 'transactionResult',
            'refundResult', 'methodsResult', 'paymentStatsResult'
        ];
        
        containers.forEach(id => {
            const container = document.getElementById(id);
            if (container) container.innerHTML = '';
        });

        // Set default values for inputs
        const processAmount = document.getElementById('processAmount');
        if (processAmount && !processAmount.value) {
            processAmount.value = '50.00';
        }

        const historyLimit = document.getElementById('historyLimit');
        if (historyLimit && !historyLimit.value) {
            historyLimit.value = '10';
        }

        console.log('Payment Service view initialized');
    }

    // Export functions
    App.payment = {
        testProcessPayment,
        testPaymentHistory,
        testTransactionDetails,
        testRequestRefund,
        testPaymentMethods,
        testPaymentStatistics,
        initPaymentView
    };

    // Export to window for inline onclick handlers
    window.testProcessPayment = testProcessPayment;
    window.testPaymentHistory = testPaymentHistory;
    window.testTransactionDetails = testTransactionDetails;
    window.testRequestRefund = testRequestRefund;
    window.testPaymentMethods = testPaymentMethods;
    window.testPaymentStatistics = testPaymentStatistics;

    console.log('Payment module loaded');
})();
