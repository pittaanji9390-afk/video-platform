/**
 * QC Review Request Validator
 */

const { isValidUUID } = require('../utils/uuid');

const ALLOWED_QC_STATUSES = ['approved', 'rejected'];

function validateCreateQCReview(req, res, next) {
  const { video_id, status, reject_reason, reviewer_name, reviewer_id } = req.body || {};
  const errors = [];

  // Validate video_id
  if (!video_id || !isValidUUID(video_id)) {
    errors.push({
      field: 'video_id',
      message: 'A valid video_id UUID is required',
    });
  }

  // Validate status
  if (!status || !ALLOWED_QC_STATUSES.includes(status)) {
    errors.push({
      field: 'status',
      message: `status is required and must be one of: ${ALLOWED_QC_STATUSES.join(', ')}`,
    });
  }

  // Validate reject_reason if status is 'rejected'
  if (status === 'rejected') {
    if (!reject_reason || typeof reject_reason !== 'string' || reject_reason.trim().length === 0) {
      errors.push({
        field: 'reject_reason',
        message: 'reject_reason is required when status is "rejected"',
      });
    }
  }

  // Validate reviewer identification (reviewer_name or reviewer_id)
  if (!reviewer_name && !reviewer_id) {
    errors.push({
      field: 'reviewer_name',
      message: 'reviewer_name or reviewer_id is required',
    });
  }

  if (reviewer_name && typeof reviewer_name !== 'string') {
    errors.push({
      field: 'reviewer_name',
      message: 'reviewer_name must be a string',
    });
  }

  if (reviewer_id && !isValidUUID(reviewer_id)) {
    errors.push({
      field: 'reviewer_id',
      message: 'reviewer_id must be a valid UUID',
    });
  }

  if (errors.length > 0) {
    return res.status(400).json({
      status: 'error',
      statusCode: 400,
      message: 'Validation Error',
      errors,
    });
  }

  req.body.video_id = video_id.trim();
  req.body.status = status.trim();
  if (reject_reason) req.body.reject_reason = reject_reason.trim();
  if (reviewer_name) req.body.reviewer_name = reviewer_name.trim();

  next();
}

module.exports = {
  validateCreateQCReview,
};
