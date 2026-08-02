/**
 * Admin Request Validator
 */

const { isValidUUID } = require('../utils/uuid');

function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return typeof email === 'string' && emailRegex.test(email.trim());
}

function validatePhone(phone) {
  const phoneRegex = /^\+?[0-9\s\-]{7,20}$/;
  return typeof phone === 'string' && phoneRegex.test(phone.trim());
}

function validateIdParam(req, res, next) {
  const { id } = req.params;
  if (!isValidUUID(id)) {
    return res.status(400).json({
      status: 'error',
      statusCode: 400,
      message: 'Invalid UUID format for admin ID',
    });
  }
  next();
}

function validateCreateAdmin(req, res, next) {
  const { full_name, email, phone, password } = req.body || {};
  const errors = [];

  if (!full_name || typeof full_name !== 'string' || full_name.trim().length < 2) {
    errors.push({
      field: 'full_name',
      message: 'full_name is required and must be at least 2 characters long',
    });
  }

  if (!email || !validateEmail(email)) {
    errors.push({
      field: 'email',
      message: 'A valid email address is required',
    });
  }

  if (!phone || !validatePhone(phone)) {
    errors.push({
      field: 'phone',
      message: 'A valid phone number is required (7 to 20 digits)',
    });
  }

  if (!password || typeof password !== 'string' || password.length < 6) {
    errors.push({
      field: 'password',
      message: 'password is required and must be at least 6 characters long',
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

  req.body.full_name = full_name.trim();
  req.body.email = email.trim().toLowerCase();
  req.body.phone = phone.trim();

  next();
}

function validateUpdateAdmin(req, res, next) {
  const { full_name, email, phone, is_active } = req.body || {};
  const errors = [];

  if (full_name !== undefined && (typeof full_name !== 'string' || full_name.trim().length < 2)) {
    errors.push({
      field: 'full_name',
      message: 'full_name must be at least 2 characters long',
    });
  }

  if (email !== undefined && !validateEmail(email)) {
    errors.push({
      field: 'email',
      message: 'A valid email address is required',
    });
  }

  if (phone !== undefined && !validatePhone(phone)) {
    errors.push({
      field: 'phone',
      message: 'A valid phone number is required',
    });
  }

  if (is_active !== undefined && typeof is_active !== 'boolean') {
    errors.push({
      field: 'is_active',
      message: 'is_active must be a boolean',
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

  if (full_name) req.body.full_name = full_name.trim();
  if (email) req.body.email = email.trim().toLowerCase();
  if (phone) req.body.phone = phone.trim();

  next();
}

module.exports = {
  validateIdParam,
  validateCreateAdmin,
  validateUpdateAdmin,
};
