/**
 * Input Sanitization Middleware
 * Protects against XSS, SQL injection, and command injection in request bodies.
 */

const crypto = require('crypto');
const logger = require('../utils/logger');

/**
 * Recursively sanitize all string values in an object
 */
function sanitizeString(str) {
  if (typeof str !== 'string') return str;
  return str
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;')
    .trim();
}

function sanitizeObject(obj) {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === 'string') return sanitizeString(obj);
  if (Array.isArray(obj)) return obj.map(sanitizeObject);
  if (typeof obj === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      // Skip __proto__ and constructor injection
      if (key === '__proto__' || key === 'constructor' || key === 'prototype') continue;
      sanitized[key] = sanitizeObject(value);
    }
    return sanitized;
  }
  return obj;
}

/**
 * Middleware to sanitize request body, query, and params
 */
function sanitizeInput(req, res, next) {
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeObject(req.body);
  }
  if (req.query && typeof req.query === 'object') {
    req.query = sanitizeObject(req.query);
  }
  if (req.params && typeof req.params === 'object') {
    req.params = sanitizeObject(req.params);
  }
  next();
}

/**
 * SQL injection pattern detector (extra layer beyond parameterized queries)
 */
const SQL_INJECTION_PATTERNS = [
  /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE|UNION|FETCH|DECLARE|TRUNCATE)\b)/i,
  /(--|;|\/\*|\*\/|xp_|sp_)/i,
  /(\b(OR|AND)\b\s+\d+\s*=\s*\d+)/i,
  /('\s*(OR|AND)\s+')/i,
  /(CHAR\(|CONCAT\(|0x[0-9a-f]+)/i,
];

function detectSQLInjection(req, res, next) {
  const check = (value) => {
    if (typeof value !== 'string') return false;
    return SQL_INJECTION_PATTERNS.some(pattern => pattern.test(value));
  };

  const checkObject = (obj) => {
    if (!obj || typeof obj !== 'object') return false;
    for (const value of Object.values(obj)) {
      if (check(value)) return true;
      if (typeof value === 'object' && checkObject(value)) return true;
    }
    return false;
  };

  if (checkObject(req.body) || checkObject(req.query) || checkObject(req.params)) {
    logger.warn('Potential SQL injection attempt detected', {
      ip: req.ip,
      path: req.originalUrl,
      method: req.method,
    });
    return res.status(400).json({
      status: 'error',
      statusCode: 400,
      message: 'Invalid input detected.',
    });
  }

  next();
}

/**
 * Request ID middleware - adds unique ID to each request for audit trail
 */
function requestId(req, res, next) {
  req.id = req.headers['x-request-id'] || crypto.randomUUID();
  res.setHeader('X-Request-Id', req.id);
  next();
}

module.exports = {
  sanitizeInput,
  detectSQLInjection,
  requestId,
  sanitizeString,
  sanitizeObject,
};
