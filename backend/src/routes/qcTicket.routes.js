/**
 * QC Ticket System Routes
 */

const express = require('express');
const router = express.Router();
const qcTicketController = require('../controllers/qcTicket.controller');
const { authenticateJWT } = require('../middleware/auth.middleware');
const { requireRole } = require('../middleware/role.middleware');

// Protect all QC Ticket Endpoints
router.use(authenticateJWT);

// Get QC Dashboard Live Database Stats (admin, qc_team)
router.get('/dashboard-stats', requireRole('admin', 'qc_team'), qcTicketController.getDashboardStats);

// Create / Assign Ticket (admin only)
router.post('/tickets', requireRole('admin'), qcTicketController.createTicket);
router.post('/tickets/assign', requireRole('admin', 'qc_team'), qcTicketController.assignTicket);
router.post('/tickets/:id/assign', requireRole('admin', 'qc_team'), qcTicketController.assignTicket);

// Get My Assigned Tickets & Dashboard Stats (qc_team only)
router.get('/tickets/my-tickets', requireRole('admin', 'qc_team'), qcTicketController.getMyTickets);

// Update Ticket Status (qc_team only)
router.patch('/tickets/:id/status', requireRole('admin', 'qc_team'), qcTicketController.updateTicketStatus);

// Record Reviewer Activity Timestamp
router.post('/tickets/reviewer-activity', requireRole('admin', 'qc_team'), qcTicketController.recordActivity);

// Manual or Admin Trigger for Auto-Reassignment / Equal Division (admin only)
router.post('/auto-divide', requireRole('admin', 'qc_team'), qcTicketController.triggerAutoReassignment);
router.post('/tickets/auto-divide', requireRole('admin', 'qc_team'), qcTicketController.triggerAutoReassignment);
router.post('/tickets/auto-reassign', requireRole('admin', 'qc_team'), qcTicketController.triggerAutoReassignment);

// Get / Update Admin System Configurations (admin only)
router.get('/admin/qc-config', requireRole('admin'), qcTicketController.getQCConfigs);
router.put('/admin/qc-config', requireRole('admin'), qcTicketController.updateQCConfigs);

module.exports = router;
