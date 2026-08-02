/**
 * Background Scheduler for QC Ticket Auto-Reassignment
 * Runs every 15 minutes to reclaim unreviewed pending_qc tickets from inactive QC reviewers (> 24h)
 * and redistribute them using the Least Workload Algorithm.
 */

const qcTicketService = require('../services/qcTicket.service');
const logger = require('../utils/logger');

// Interval frequency: 15 minutes (15 * 60 * 1000 ms)
const CHECK_INTERVAL_MS = 15 * 60 * 1000;

function startQCScheduler() {
  logger.info('⏰ QC Ticket Auto-Reassignment Background Scheduler Initialized (Runs every 15 minutes)');

  // Run initial check 30 seconds after server startup
  setTimeout(async () => {
    try {
      logger.info('🔍 Running initial QC Inactivity Check & Auto-Reassignment...');
      await qcTicketService.autoReassignInactiveReviewers();
    } catch (err) {
      logger.error('Error in initial QC scheduler execution', { error: err.message });
    }
  }, 30000);

  // Set recurring timer every 15 minutes
  setInterval(async () => {
    try {
      logger.info('🔍 Executing 15-minute QC Reviewer Inactivity Check & Reassignment Routine...');
      const result = await qcTicketService.autoReassignInactiveReviewers();
      if (result.reassigned_count > 0) {
        logger.info(`✓ Auto-Reassigned ${result.reassigned_count} tickets from ${result.inactive_reviewers_count} inactive reviewers.`);
      }
    } catch (err) {
      logger.error('Error executing recurring QC scheduler:', { error: err.message });
    }
  }, CHECK_INTERVAL_MS);
}

module.exports = { startQCScheduler };
