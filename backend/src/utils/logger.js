/**
 * Logger Configuration
 * 
 * Centralized logging utility for the backend application.
 * Provides structured log methods (info, warn, error, debug)
 * with timestamps and log level prefixes.
 * 
 * In production, logs can be extended to write to files or
 * external logging services (e.g., CloudWatch, Datadog).
 */

const config = require('../config');

const LOG_LEVELS = {
  ERROR: 'ERROR',
  WARN: 'WARN',
  INFO: 'INFO',
  DEBUG: 'DEBUG',
};

/**
 * Formats a log message with timestamp and level.
 */
function formatMessage(level, message, meta = null) {
  const timestamp = new Date().toISOString();
  const base = `[${timestamp}] [${level}] ${message}`;
  if (meta) {
    return `${base} ${JSON.stringify(meta)}`;
  }
  return base;
}

const logger = {
  info(message, meta = null) {
    console.log(formatMessage(LOG_LEVELS.INFO, message, meta));
  },

  warn(message, meta = null) {
    console.warn(formatMessage(LOG_LEVELS.WARN, message, meta));
  },

  error(message, meta = null) {
    console.error(formatMessage(LOG_LEVELS.ERROR, message, meta));
  },

  debug(message, meta = null) {
    if (config.nodeEnv === 'development') {
      console.debug(formatMessage(LOG_LEVELS.DEBUG, message, meta));
    }
  },
};

module.exports = logger;
