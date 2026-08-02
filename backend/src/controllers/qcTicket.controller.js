/**
 * QC Ticket Controller
 * REST API Handlers for Ticket Management, Auto-Reassignment, Activity Tracking, and Audit Logging
 */

const qcTicketService = require('../services/qcTicket.service');

class QCTicketController {
  async getDashboardStats(req, res, next) {
    try {
      const reviewerId = req.user?.id || req.query.reviewer_id || null;
      const stats = await qcTicketService.getQCDashboardStats(reviewerId);
      return res.status(200).json({
        status: 'success',
        data: stats,
      });
    } catch (err) {
      next(err);
    }
  }

  async createTicket(req, res, next) {
    try {
      const ticket = await qcTicketService.createTicketForVideo(req.body);
      return res.status(201).json({
        status: 'success',
        message: 'QC ticket created and assigned',
        data: ticket,
      });
    } catch (err) {
      next(err);
    }
  }

  async getMyTickets(req, res, next) {
    try {
      const reviewerId = req.user?.id || req.query.reviewer_id || 'a0000000-0000-0000-0000-000000000001';
      const statusFilter = req.query.status || null;

      const result = await qcTicketService.getMyAssignedTickets(reviewerId, statusFilter);
      return res.status(200).json({
        status: 'success',
        data: result.tickets,
        statistics: result.statistics,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateTicketStatus(req, res, next) {
    try {
      const { id } = req.params;
      const { status } = req.body;

      const reviewerId = req.user?.id;
      await qcTicketService.updateTicketStatus(id, status, reviewerId);
      await qcTicketService.updateReviewerActivity(reviewerId, 'review_submission');

      return res.status(200).json({
        status: 'success',
        message: `Ticket ${id} status updated to ${status}`,
      });
    } catch (err) {
      next(err);
    }
  }

  async recordActivity(req, res, next) {
    try {
      const reviewerId = req.user?.id || req.body.reviewer_id;
      const activityType = req.body.activity_type || 'dashboard_view';
      const reviewerName = req.user?.name || req.body.reviewer_name;
      const reviewerEmail = req.user?.email || req.body.reviewer_email;

      const result = await qcTicketService.updateReviewerActivity(reviewerId, activityType, reviewerName, reviewerEmail);
      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async triggerAutoReassignment(req, res, next) {
    try {
      const result = await qcTicketService.triggerAutoReassignmentForInactiveReviewers();
      return res.status(200).json({
        status: 'success',
        message: 'Auto-reassignment executed successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getReviewerActivity(req, res, next) {
    try {
      const reviewers = await qcTicketService.getAllReviewersActivity();
      return res.status(200).json({
        status: 'success',
        data: reviewers,
      });
    } catch (err) {
      next(err);
    }
  }

  async getQCConfigs(req, res, next) {
    try {
      const configs = await qcTicketService.getAllQCConfigs();
      return res.status(200).json({
        status: 'success',
        data: configs,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateQCConfigs(req, res, next) {
    try {
      const configs = await qcTicketService.updateQCConfigs(req.body);
      return res.status(200).json({
        status: 'success',
        message: 'QC System Configuration Updated',
        data: configs,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new QCTicketController();
