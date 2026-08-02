/**
 * Vendor Request Validator
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

function validateVendorIdParam(req, res, next) {
  const { id } = req.params;
  if (!isValidUUID(id)) {
    return res.status(400).json({
      status: 'error',
      statusCode: 400,
      message: 'Invalid UUID format for vendor ID',
    });
  }
  next();
}

function validateCreateVendor(req, res, next) {
  const { company_name, contact_person, email, phone, address } = req.body || {};
  const errors = [];

  if (!company_name || typeof company_name !== 'string' || company_name.trim().length < 2) {
    errors.push({
      field: 'company_name',
      message: 'company_name is required and must be at least 2 characters long',
    });
  }

  if (!contact_person || typeof contact_person !== 'string' || contact_person.trim().length < 2) {
    errors.push({
      field: 'contact_person',
      message: 'contact_person is required and must be at least 2 characters long',
    });
  }

  if (!email || !validateEmail(email)) {
    errors.push({
      field: 'email',
      message: 'A valid email address is required',
    });
  }

  if (phone && !validatePhone(phone)) {
    errors.push({
      field: 'phone',
      message: 'Invalid phone number format',
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

  req.body.company_name = company_name.trim();
  req.body.contact_person = contact_person.trim();
  req.body.email = email.trim().toLowerCase();
  if (phone) req.body.phone = phone.trim();
  if (address) req.body.address = address.trim();

  next();
}

function validateUpdateVendor(req, res, next) {
  const { company_name, contact_person, email, phone, address, is_active } = req.body || {};
  const errors = [];

  if (company_name !== undefined && (typeof company_name !== 'string' || company_name.trim().length < 2)) {
    errors.push({
      field: 'company_name',
      message: 'company_name must be at least 2 characters long',
    });
  }

  if (contact_person !== undefined && (typeof contact_person !== 'string' || contact_person.trim().length < 2)) {
    errors.push({
      field: 'contact_person',
      message: 'contact_person must be at least 2 characters long',
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
      message: 'Invalid phone number format',
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

  if (company_name) req.body.company_name = company_name.trim();
  if (contact_person) req.body.contact_person = contact_person.trim();
  if (email) req.body.email = email.trim().toLowerCase();
  if (phone) req.body.phone = phone.trim();
  if (address) req.body.address = address.trim();

  next();
}

module.exports = {
  validateVendorIdParam,
  validateCreateVendor,
  validateUpdateVendor,
};
