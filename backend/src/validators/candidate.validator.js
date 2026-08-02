/**
 * Candidate Request Validator
 */

const { isValidUUID } = require('../utils/uuid');

function validatePhone(phone) {
  const phoneRegex = /^\+?[0-9\s\-]{7,20}$/;
  return typeof phone === 'string' && phoneRegex.test(phone.trim());
}

function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return typeof email === 'string' && emailRegex.test(email.trim());
}

function validateCreateCandidate(req, res, next) {
  const { vendor_id, full_name, phone, email } = req.body || {};
  const errors = [];

  if (!vendor_id || !isValidUUID(vendor_id)) {
    errors.push({
      field: 'vendor_id',
      message: 'A valid vendor_id UUID is required',
    });
  }

  if (!full_name || typeof full_name !== 'string' || full_name.trim().length < 2) {
    errors.push({
      field: 'full_name',
      message: 'full_name is required and must be at least 2 characters long',
    });
  }

  if (!phone || !validatePhone(phone)) {
    errors.push({
      field: 'phone',
      message: 'A valid phone number is required (7 to 20 digits)',
    });
  }

  if (email && !validateEmail(email)) {
    errors.push({
      field: 'email',
      message: 'Invalid email address format',
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

  req.body.vendor_id = vendor_id.trim();
  req.body.full_name = full_name.trim();
  req.body.phone = phone.trim();
  if (email) req.body.email = email.trim().toLowerCase();

  next();
}

function validateGetCandidatesQuery(req, res, next) {
  const { vendor_id } = req.query;
  if (vendor_id && !isValidUUID(vendor_id)) {
    return res.status(400).json({
      status: 'error',
      statusCode: 400,
      message: 'Invalid vendor_id UUID in query parameters',
    });
  }
  next();
}

module.exports = {
  validateCreateCandidate,
  validateGetCandidatesQuery,
};
