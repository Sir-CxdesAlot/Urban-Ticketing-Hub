/**
 * Role-Based Testing Module
 * Comprehensive test suite for User Roles System
 * Phase 4: Security & Testing
 */

(function() {
    'use strict';

    const App = (window.App = window.App || {});

    // Test results storage
    const testResults = {
        total: 0,
        passed: 0,
        failed: 0,
        skipped: 0,
        tests: []
    };

    /**
     * Test runner
     */
    function runTest(testName, testFunction) {
        testResults.total++;
        
        try {
            const result = testFunction();
            
            if (result === 'SKIP') {
                testResults.skipped++;
                testResults.tests.push({
                    name: testName,
                    status: 'SKIPPED',
                    message: 'Test skipped',
                    timestamp: new Date().toISOString()
                });
                console.log(`⏭️  [SKIP] ${testName}`);
            } else if (result) {
                testResults.passed++;
                testResults.tests.push({
                    name: testName,
                    status: 'PASSED',
                    message: 'Test passed',
                    timestamp: new Date().toISOString()
                });
                console.log(`✅ [PASS] ${testName}`);
            } else {
                throw new Error('Test returned false');
            }
        } catch (error) {
            testResults.failed++;
            testResults.tests.push({
                name: testName,
                status: 'FAILED',
                message: error.message,
                error: error.stack,
                timestamp: new Date().toISOString()
            });
            console.error(`❌ [FAIL] ${testName}:`, error.message);
        }
    }

    /**
     * Test Suite: Role System
     */
    function testRoleSystem() {
        console.log('\n🧪 Testing Role System...\n');

        const api = window.App?.api || window.APIModule;

        runTest('ROLES constant exists', () => {
            return api && api.ROLES && typeof api.ROLES === 'object';
        });

        runTest('All 5 roles defined', () => {
            const requiredRoles = ['GUEST', 'PASSENGER', 'ROUTE_OPERATOR', 'TRANSPORT_MANAGER', 'SUPER_ADMIN'];
            return requiredRoles.every(role => api.ROLES[role]);
        });

        runTest('Role levels are correct', () => {
            return api.ROLES.GUEST.level === 1 &&
                   api.ROLES.PASSENGER.level === 2 &&
                   api.ROLES.ROUTE_OPERATOR.level === 3 &&
                   api.ROLES.TRANSPORT_MANAGER.level === 4 &&
                   api.ROLES.SUPER_ADMIN.level === 5;
        });

        runTest('Role icons are set', () => {
            return Object.values(api.ROLES).every(role => role.icon && role.icon.length > 0);
        });

        runTest('Role labels are set', () => {
            return Object.values(api.ROLES).every(role => role.label && role.label.length > 0);
        });

        runTest('Role permissions are arrays', () => {
            return Object.values(api.ROLES).every(role => Array.isArray(role.permissions));
        });
    }

    /**
     * Test Suite: Permission System
     */
    function testPermissionSystem() {
        console.log('\n🔐 Testing Permission System...\n');

        const api = window.App?.api || window.APIModule;

        runTest('hasPermission function exists', () => {
            return typeof api.hasPermission === 'function';
        });

        runTest('hasMinimumRole function exists', () => {
            return typeof api.hasMinimumRole === 'function';
        });

        runTest('hasRoleLevel function exists', () => {
            return typeof api.hasRoleLevel === 'function';
        });

        runTest('Guest has VIEW_PUBLIC_ROUTES permission', () => {
            const original = { ...api.session };
            api.session.userRole = 'GUEST';
            const result = api.hasPermission('VIEW_PUBLIC_ROUTES');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Guest does not have PURCHASE_TICKETS permission', () => {
            const original = { ...api.session };
            api.session.userRole = 'GUEST';
            const result = !api.hasPermission('PURCHASE_TICKETS');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Passenger has PURCHASE_TICKETS permission', () => {
            const original = { ...api.session };
            api.session.userRole = 'PASSENGER';
            const result = api.hasPermission('PURCHASE_TICKETS');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Route Operator has VALIDATE_TICKETS permission', () => {
            const original = { ...api.session };
            api.session.userRole = 'ROUTE_OPERATOR';
            const result = api.hasPermission('VALIDATE_TICKETS');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Transport Manager has CREATE_ROUTES permission', () => {
            const original = { ...api.session };
            api.session.userRole = 'TRANSPORT_MANAGER';
            const result = api.hasPermission('CREATE_ROUTES');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Super Admin has MANAGE_USERS permission', () => {
            const original = { ...api.session };
            api.session.userRole = 'SUPER_ADMIN';
            const result = api.hasPermission('MANAGE_USERS');
            Object.assign(api.session, original);
            return result;
        });
    }

    /**
     * Test Suite: Role Hierarchy
     */
    function testRoleHierarchy() {
        console.log('\n📊 Testing Role Hierarchy...\n');

        const api = window.App?.api || window.APIModule;

        runTest('Passenger has minimum role GUEST', () => {
            const original = { ...api.session };
            api.session.userRole = 'PASSENGER';
            const result = api.hasMinimumRole('GUEST');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Route Operator has minimum role PASSENGER', () => {
            const original = { ...api.session };
            api.session.userRole = 'ROUTE_OPERATOR';
            const result = api.hasMinimumRole('PASSENGER');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Transport Manager has minimum role ROUTE_OPERATOR', () => {
            const original = { ...api.session };
            api.session.userRole = 'TRANSPORT_MANAGER';
            const result = api.hasMinimumRole('ROUTE_OPERATOR');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Super Admin has minimum role TRANSPORT_MANAGER', () => {
            const original = { ...api.session };
            api.session.userRole = 'SUPER_ADMIN';
            const result = api.hasMinimumRole('TRANSPORT_MANAGER');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Guest does NOT have minimum role PASSENGER', () => {
            const original = { ...api.session };
            api.session.userRole = 'GUEST';
            const result = !api.hasMinimumRole('PASSENGER');
            Object.assign(api.session, original);
            return result;
        });

        runTest('Passenger does NOT have minimum role TRANSPORT_MANAGER', () => {
            const original = { ...api.session };
            api.session.userRole = 'PASSENGER';
            const result = !api.hasMinimumRole('TRANSPORT_MANAGER');
            Object.assign(api.session, original);
            return result;
        });
    }

    /**
     * Test Suite: Session Management
     */
    function testSessionManagement() {
        console.log('\n🔒 Testing Session Management...\n');

        const api = window.App?.api || window.APIModule;

        runTest('Session object exists', () => {
            return api.session && typeof api.session === 'object';
        });

        runTest('Session has required properties', () => {
            return 'loggedIn' in api.session &&
                   'userRole' in api.session &&
                   'guestMode' in api.session;
        });

        runTest('initGuestMode function exists', () => {
            return typeof api.initGuestMode === 'function';
        });

        runTest('saveSession function exists', () => {
            return typeof api.saveSession === 'function';
        });

        runTest('loadSession function exists', () => {
            return typeof api.loadSession === 'function';
        });

        runTest('Guest mode sets correct role', () => {
            api.initGuestMode();
            return api.session.userRole === 'GUEST' && api.session.guestMode === true;
        });
    }

    /**
     * Test Suite: Permissions Module
     */
    function testPermissionsModule() {
        console.log('\n🎯 Testing Permissions Module...\n');

        const perms = window.PermissionsModule;

        if (!perms) {
            runTest('PermissionsModule exists', () => false);
            return;
        }

        runTest('PermissionsModule exists', () => !!perms);

        runTest('shouldShowElement function exists', () => {
            return typeof perms.shouldShowElement === 'function';
        });

        runTest('applyPermissionBasedUI function exists', () => {
            return typeof perms.applyPermissionBasedUI === 'function';
        });

        runTest('getRoleSpecificContent function exists', () => {
            return typeof perms.getRoleSpecificContent === 'function';
        });

        runTest('refresh function exists', () => {
            return typeof perms.refresh === 'function';
        });
    }

    /**
     * Test Suite: Security Module
     */
    function testSecurityModule() {
        console.log('\n🛡️ Testing Security Module...\n');

        const security = window.SecurityModule;

        if (!security) {
            runTest('SecurityModule exists', () => false);
            return;
        }

        runTest('SecurityModule exists', () => !!security);

        runTest('createAuditLog function exists', () => {
            return typeof security.createAuditLog === 'function';
        });

        runTest('getAuditLogs function exists', () => {
            return typeof security.getAuditLogs === 'function';
        });

        runTest('authorize function exists', () => {
            return typeof security.authorize === 'function';
        });

        runTest('authorizeRole function exists', () => {
            return typeof security.authorizeRole === 'function';
        });

        runTest('trackLoginAttempt function exists', () => {
            return typeof security.trackLoginAttempt === 'function';
        });

        runTest('isAccountLocked function exists', () => {
            return typeof security.isAccountLocked === 'function';
        });

        runTest('getSecurityStats function exists', () => {
            return typeof security.getSecurityStats === 'function';
        });

        runTest('AUDIT_TYPES constant exists', () => {
            return security.AUDIT_TYPES && typeof security.AUDIT_TYPES === 'object';
        });

        runTest('SECURITY_CONFIG constant exists', () => {
            return security.SECURITY_CONFIG && typeof security.SECURITY_CONFIG === 'object';
        });
    }

    /**
     * Test Suite: Menu Module
     */
    function testMenuModule() {
        console.log('\n📋 Testing Menu Module...\n');

        const menu = window.MenuModule;

        if (!menu) {
            runTest('MenuModule exists', () => false);
            return;
        }

        runTest('MenuModule exists', () => !!menu);

        runTest('hasServiceAccess function exists', () => {
            return typeof menu.hasServiceAccess === 'function';
        });

        runTest('updateMenuVisibility function exists', () => {
            return typeof menu.updateMenuVisibility === 'function';
        });
    }

    /**
     * Test Suite: UI Components
     */
    function testUIComponents() {
        console.log('\n🎨 Testing UI Components...\n');

        runTest('Role badge element exists', () => {
            return !!document.getElementById('roleBadge');
        });

        runTest('Guest banner element exists', () => {
            return !!document.getElementById('guestBanner');
        });

        runTest('Service menu exists', () => {
            return !!document.getElementById('serviceMenu');
        });

        runTest('Login button exists', () => {
            return !!document.getElementById('loginBtn');
        });
    }

    /**
     * Run all tests
     */
    function runAllTests() {
        console.clear();
        console.log('═══════════════════════════════════════════════');
        console.log('🧪 User Roles System - Test Suite');
        console.log('   Phase 4: Security & Testing');
        console.log('═══════════════════════════════════════════════');

        // Reset results
        testResults.total = 0;
        testResults.passed = 0;
        testResults.failed = 0;
        testResults.skipped = 0;
        testResults.tests = [];

        // Run test suites
        testRoleSystem();
        testPermissionSystem();
        testRoleHierarchy();
        testSessionManagement();
        testPermissionsModule();
        testSecurityModule();
        testMenuModule();
        testUIComponents();

        // Print summary
        printTestSummary();

        return testResults;
    }

    /**
     * Print test summary
     */
    function printTestSummary() {
        console.log('\n═══════════════════════════════════════════════');
        console.log('📊 Test Summary');
        console.log('═══════════════════════════════════════════════');
        console.log(`Total Tests:   ${testResults.total}`);
        console.log(`✅ Passed:      ${testResults.passed} (${Math.round(testResults.passed/testResults.total*100)}%)`);
        console.log(`❌ Failed:      ${testResults.failed} (${Math.round(testResults.failed/testResults.total*100)}%)`);
        console.log(`⏭️  Skipped:     ${testResults.skipped} (${Math.round(testResults.skipped/testResults.total*100)}%)`);
        console.log('═══════════════════════════════════════════════');

        if (testResults.failed === 0) {
            console.log('🎉 All tests passed!');
        } else {
            console.log('⚠️  Some tests failed. Review errors above.');
        }

        console.log('═══════════════════════════════════════════════\n');
    }

    /**
     * Get test results
     */
    function getTestResults() {
        return { ...testResults };
    }

    /**
     * Export testing module
     */
    const TestingModule = {
        runAllTests,
        getTestResults,
        runTest,
        
        // Individual test suites
        testRoleSystem,
        testPermissionSystem,
        testRoleHierarchy,
        testSessionManagement,
        testPermissionsModule,
        testSecurityModule,
        testMenuModule,
        testUIComponents
    };

    // Export to global namespace
    window.TestingModule = TestingModule;
    App.testing = TestingModule;

    // Add console command
    console.log('[Testing] Testing module loaded. Run tests with: TestingModule.runAllTests()');

})();
