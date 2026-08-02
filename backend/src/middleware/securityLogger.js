/**
 * Security Event Logger
 * Tracks security-relevant events for audit trail and intrusion detection.
 */

const logger = require('../utils/logger');

const SECURITY_EVENTS = {
  LOGIN_SUCCESS: 'LOGIN_SUCCESS',
  LOGIN_FAILURE: 'LOGIN_FAILURE',
  LOGOUT: 'LOGOUT',
  PASSWORD_CHANGE: 'PASSWORD_CHANGE',
  PASSWORD_RESET: 'PASSWORD_RESET',
  ACCOUNT_LOCKED: 'ACCOUNT_LOCKED',
  UNAUTHORIZED_ACCESS: 'UNAUTHORIZED_ACCESS',
  FORBIDDEN_ACCESS: 'FORBIDDEN_ACCESS',
  TOKEN_REFRESH: 'TOKEN_REFRESH',
  TOKEN_REVOKED: 'TOKEN_REVOKED',
  ADMIN_ACTION: 'ADMIN_ACTION',
  FILE_UPLOAD: 'FILE_UPLOAD',
  FILE_VIEW: 'FILE_VIEW',
  FILE_DOWNLOAD: 'FILE_DOWNLOAD',
  FILE_DELETE: 'FILE_DELETE',
  DATA_EXPORT: 'DATA_EXPORT',
  SUSPICIOUS_ACTIVITY: 'SUSPICIOUS_ACTIVITY',
  RATE_LIMIT_HIT: 'RATE_LIMIT_HIT',
  SQL_INJECTION_ATTEMPT: 'SQL_INJECTION_ATTEMPT',
  XSS_ATTEMPT: 'XSS_ATTEMPT',
};

class SecurityLogger {
  /**
   * Log a security event
   */
  static log(eventType, details = {}) {
    const entry = {
      timestamp: new Date().toISOString(),
      event: eventType,
      ip: details.ip || 'unknown',
      userId: details.userId || null,
      userAgent: details.userAgent || 'unknown',
      path: details.path || 'unknown',
      method: details.method || 'unknown',
      requestId: details.requestId || null,
      message: details.message || eventType,
      metadata: details.metadata || {},
    };

    // Log as warning for suspicious events, info for normal events
    const suspiciousEvents = [
      SECURITY_EVENTS.LOGIN_FAILURE,
      SECURITY_EVENTS.UNAUTHORIZED_ACCESS,
      SECURITY_EVENTS.FORBIDDEN_ACCESS,
      SECURITY_EVENTS.SUSPICIOUS_ACTIVITY,
      SECURITY_EVENTS.RATE_LIMIT_HIT,
      SECURITY_EVENTS.SQL_INJECTION_ATTEMPT,
      SECURITY_EVENTS.XSS_ATTEMPT,
    ];

    if (suspiciousEvents.includes(eventType)) {
      logger.warn(`[SECURITY] ${eventType}`, entry);
    } else {
      logger.info(`[SECURITY] ${eventType}`, entry);
    }

    return entry;
  }

  /**
   * Express middleware to log security events
   */
  static middleware(eventType) {
    return (req, res, next) => {
      SecurityLogger.log(eventType, {
        ip: req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip,
        userId: req.user?.id || null,
        userAgent: req.headers['user-agent'],
        path: req.originalUrl,
        method: req.method,
        requestId: req.id || null,
      });
      next();
    };
  }
}

module.exports = { SecurityLogger, SECURITY_EVENTS };
