// MongoDB initialization script for Ticketing Platform
// Updated: 2025-10-04
// - Changed database name to 'ticketing_platform' (matches services)
// - Updated sample credentials to match initialize-test-data scripts
// - Enhanced indexes for better performance
// - Added more comprehensive sample data

// Switch to the ticketing platform database
db = db.getSiblingDB('ticketing_platform');

// Create collections with indexes for better performance

// Users collection
db.createCollection('users');
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "id": 1 }, { unique: true });

// Routes collection
db.createCollection('routes');
db.routes.createIndex({ "id": 1 }, { unique: true });
db.routes.createIndex({ "routeNumber": 1 }, { unique: true });

// Trips collection
db.createCollection('trips');
db.trips.createIndex({ "id": 1 }, { unique: true });
db.trips.createIndex({ "routeId": 1 });
db.trips.createIndex({ "departureTime": 1 });

// Tickets collection
db.createCollection('tickets');
db.tickets.createIndex({ "id": 1 }, { unique: true });
db.tickets.createIndex({ "passengerId": 1 });
db.tickets.createIndex({ "routeId": 1 });
db.tickets.createIndex({ "status": 1 });
db.tickets.createIndex({ "createdAt": 1 });

// Payments collection
db.createCollection('payments');
db.payments.createIndex({ "id": 1 }, { unique: true });
db.payments.createIndex({ "ticketId": 1 });
db.payments.createIndex({ "passengerId": 1 });
db.payments.createIndex({ "status": 1 });

// Notifications collection
db.createCollection('notifications');
db.notifications.createIndex({ "id": 1 }, { unique: true });
db.notifications.createIndex({ "recipientId": 1 });
db.notifications.createIndex({ "type": 1 });
db.notifications.createIndex({ "status": 1 });

// Service disruptions collection
db.createCollection('service_disruptions');
db.service_disruptions.createIndex({ "id": 1 }, { unique: true });
db.service_disruptions.createIndex({ "routeId": 1 });
db.service_disruptions.createIndex({ "status": 1 });

// Admin users collection
db.createCollection('admin_users');
db.admin_users.createIndex({ "id": 1 }, { unique: true });
db.admin_users.createIndex({ "username": 1 }, { unique: true });
db.admin_users.createIndex({ "email": 1 }, { unique: true });
db.admin_users.createIndex({ "role": 1 });

// Insert sample data for testing

// Sample admin users (matching initialize-test-data scripts)
db.admin_users.insertMany([
    {
        "id": "admin-001",
        "username": "admin",
        "email": "admin@windhoek-transport.na",
        "password": "Admin123!", // In production, this should be hashed with bcrypt
        "role": "SUPER_ADMIN",
        "createdAt": new Date().toISOString()
    },
    {
        "id": "admin-002",
        "username": "transport_manager",
        "email": "manager@windhoek-transport.na",
        "password": "Manager123!", // In production, this should be hashed with bcrypt
        "role": "TRANSPORT_MANAGER",
        "createdAt": new Date().toISOString()
    },
    {
        "id": "admin-003",
        "username": "route_operator",
        "email": "operator@windhoek-transport.na",
        "password": "Operator123!", // In production, this should be hashed with bcrypt
        "role": "ROUTE_OPERATOR",
        "createdAt": new Date().toISOString()
    }
]);

// Sample routes (matching initialize-test-data scripts)
db.routes.insertMany([
    {
        "name": "City Center - Katutura",
        "startLocation": "City Center",
        "endLocation": "Katutura",
        "intermediateStops": ["Independence Avenue", "Hospital", "Soweto Market"],
        "transportType": "BUS",
        "basePrice": 15.50,
        "isActive": true,
        "createdAt": new Date().toISOString()
    },
    {
        "name": "Windhoek Central - Airport",
        "startLocation": "Windhoek Central Station",
        "endLocation": "Hosea Kutako Airport",
        "intermediateStops": ["Eros", "Klein Windhoek", "Daan Viljoen"],
        "transportType": "TRAIN",
        "basePrice": 45.00,
        "isActive": true,
        "createdAt": new Date().toISOString()
    },
    {
        "name": "Khomasdal Circuit",
        "startLocation": "Khomasdal",
        "endLocation": "Khomasdal",
        "intermediateStops": ["Goreangab", "Wanaheda", "Greenwell Matongo"],
        "transportType": "BUS",
        "basePrice": 12.00,
        "isActive": true,
        "createdAt": new Date().toISOString()
    },
    {
        "name": "Northern Express",
        "startLocation": "Windhoek",
        "endLocation": "Oshakati",
        "intermediateStops": ["Okahandja", "Otjiwarongo", "Otavi", "Tsumeb"],
        "transportType": "TRAIN",
        "basePrice": 120.00,
        "isActive": true,
        "createdAt": new Date().toISOString()
    },
    {
        "name": "University Shuttle",
        "startLocation": "City Center",
        "endLocation": "University of Namibia",
        "intermediateStops": ["Zoo Park", "Pioneers Park"],
        "transportType": "BUS",
        "basePrice": 8.50,
        "isActive": true,
        "createdAt": new Date().toISOString()
    }
]);

// Sample trips (one per route for initial setup)
// Note: initialize-test-data scripts will create 7 trips per route
const routes = db.routes.find().toArray();
const sampleTrips = [];

routes.forEach(route => {
    sampleTrips.push({
        "routeId": route._id.toString(),
        "departureTime": "08:00",
        "arrivalTime": "09:30",
        "availableSeats": 45,
        "totalSeats": 45,
        "status": "SCHEDULED",
        "createdAt": new Date().toISOString()
    });
});

if (sampleTrips.length > 0) {
    db.trips.insertMany(sampleTrips);
}

// Sample passenger users (matching initialize-test-data scripts)
db.users.insertMany([
    {
        "firstName": "John",
        "lastName": "Doe",
        "email": "john.doe@example.com",
        "password": "JohnDoe123!", // In production, this should be hashed with bcrypt
        "phone": "+264811234567",
        "createdAt": new Date().toISOString()
    },
    {
        "firstName": "Jane",
        "lastName": "Smith",
        "email": "jane.smith@example.com",
        "password": "JaneSmith123!", // In production, this should be hashed with bcrypt
        "phone": "+264811234568",
        "createdAt": new Date().toISOString()
    },
    {
        "firstName": "Mike",
        "lastName": "Johnson",
        "email": "mike.johnson@example.com",
        "password": "MikeJohnson123!", // In production, this should be hashed with bcrypt
        "phone": "+264811234569",
        "createdAt": new Date().toISOString()
    }
]);

print("✅ MongoDB initialization completed successfully!");
print("📊 Database: 'ticketing_platform'");
print("📊 Collections: users, routes, trips, tickets, payments, notifications, service_disruptions, admin_users");
print("");
print("🔑 Sample Admin Users:");
print("   • admin / Admin123! (SUPER_ADMIN)");
print("   • transport_manager / Manager123! (TRANSPORT_MANAGER)");
print("   • route_operator / Operator123! (ROUTE_OPERATOR)");
print("");
print("👤 Sample Passenger Users:");
print("   • john.doe@example.com / JohnDoe123!");
print("   • jane.smith@example.com / JaneSmith123!");
print("   • mike.johnson@example.com / MikeJohnson123!");
print("");
print("🚌 Created 5 sample routes and initial trips");
print("");
print("� Next Steps:");
print("   Run initialize-test-data.ps1 or .sh to populate comprehensive test data");
print("   This will add more passengers, trips (7 per route), tickets, and disruptions");
print("");
print("🚀 Database is ready for the Windhoek Ticketing Platform!");