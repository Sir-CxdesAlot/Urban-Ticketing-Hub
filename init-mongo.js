// Least privilege: applications use the new database; only bootstrap uses the root account.
const demo = db.getSiblingDB('uth_demo_v2');
demo.createUser({ user: 'uth_app', pwd: process.env.MONGO_APP_PASSWORD,
    roles: [{ role: 'readWrite', db: 'uth_demo_v2' }] });
// Create demo accounts and transport explicitly with: pwsh ./uth.ps1 seed
