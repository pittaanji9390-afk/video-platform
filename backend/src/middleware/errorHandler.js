/**
 * Centralized Error Handling Middleware
 * 
 * Catches all errors thrown or passed via next(error) in Express.
 * Returns a consistent JSON error response format.
 * 
 * In development: includes the error stack trace for debugging.
 * In production:  hides internal details, returns generic message.
 * 
 * Must be registered AFTER all routes in app.js (Express reads
 * the 4-parameter signature to identify it as an error handler).
 */

const config = require('../config');
const logger = require('../utils/logger');

function errorHandler(err, req, res, next) {
  // Log the full error internally
  logger.error(`${err.message}`, {
    method: req.method,
    url: req.originalUrl,
    stack: err.stack,
  });

  const statusCode = err.statusCode || 500;

  const response = {
    status: 'error',
    statusCode,
    message: err.message || 'Internal Server Error',
  };

  // Include stack trace only in development
  if (config.nodeEnv === 'development') {
    response.stack = err.stack;
  }

  res.status(statusCode).json(response);
}

module.exports = errorHandler;
