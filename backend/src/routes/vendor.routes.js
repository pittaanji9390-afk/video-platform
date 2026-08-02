/**
 * Vendor Routes
 * Endpoints under /api/v1/vendors
 */

const express = require('express');
const router = express.Router();
const vendorController = require('../controllers/vendor.controller');
const { authenticateJWT, optionalAuth } = require('../middleware/auth.middleware');
const { requireRole } = require('../middleware/role.middleware');
const { dashboardLimiter } = require('../middleware/rateLimiter');

// GET /api/v1/vendors - Get All Vendors (Dropdowns)
router.get('/', optionalAuth, (req, res, next) => vendorController.getAllVendors(req, res, next));

// Protect private vendor endpoints
router.use(authenticateJWT);

// GET /api/v1/vendors/dashboard-stats - Live Vendor Database Aggregations
router.get('/dashboard-stats', dashboardLimiter, (req, res, next) => vendorController.getDashboardStats(req, res, next));

// POST /api/v1/vendors - Create Vendor (admin only)
router.post('/', requireRole('admin'), (req, res, next) => vendorController.createVendor(req, res, next));

// GET /api/v1/vendors/:id - Get Vendor by ID
router.get('/:id', (req, res, next) => vendorController.getVendorById(req, res, next));

// PUT /api/v1/vendors/:id - Update Vendor (admin only)
router.put('/:id', requireRole('admin'), (req, res, next) => vendorController.updateVendor(req, res, next));

// DELETE /api/v1/vendors/:id - Soft Delete Vendor (admin only)
router.delete('/:id', requireRole('admin'), (req, res, next) => vendorController.deleteVendor(req, res, next));

module.exports = router;
