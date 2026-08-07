/**
 * Auth Routes
 * Endpoints under /api/v1/auth
 * All auth endpoints are rate-limited to prevent brute-force attacks.
 */

const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authenticateJWT } = require('../middleware/auth.middleware');
const { validateLogin, validateRefreshToken } = require('../validators/auth.validator');
const { authLimiter } = require('../middleware/rateLimiter');
const { validatePasswordMiddleware } = require('../middleware/passwordValidator');
const { SecurityLogger, SECURITY_EVENTS } = require('../middleware/securityLogger');
const TokenRevocation = require('../services/tokenRevocation.service');

// POST /api/v1/auth/login - Login with email and password
router.post('/login', authLimiter, validateLogin, (req, res, next) => {
  SecurityLogger.log(SECURITY_EVENTS.LOGIN_ATTEMPT, {
    ip: req.ip,
    path: req.originalUrl,
    method: req.method,
    message: `Login attempt for: ${req.body?.email || 'unknown'}`,
  });
  authController.login(req, res, next);
});

// POST /api/v1/auth/signup - Register candidate account with vendor code
router.post('/signup', authLimiter, validatePasswordMiddleware, (req, res, next) => authController.signup(req, res, next));

// POST /api/v1/auth/refresh - Refresh Access Token using Refresh Token
router.post('/refresh', authLimiter, validateRefreshToken, (req, res, next) => authController.refreshToken(req, res, next));

// POST /api/v1/auth/logout - Revoke current token
router.post('/logout', authenticateJWT, (req, res) => {
  const authHeader = req.headers.authorization;
  if (authHeader) {
    const token = authHeader.split(' ')[1];
    TokenRevocation.revoke(token);
  }

  SecurityLogger.log(SECURITY_EVENTS.LOGOUT, {
    ip: req.ip,
    userId: req.user?.id,
    path: req.originalUrl,
    method: req.method,
    message: 'User logged out',
  });

  return res.status(200).json({
    status: 'success',
    message: 'Logged out successfully. Token revoked.',
  });
});

// GET /api/v1/auth/me - Current user profile details
router.get('/me', authenticateJWT, (req, res, next) => authController.getMe(req, res, next));

module.exports = router;
