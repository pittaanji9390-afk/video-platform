/**
 * Rate Limiting Middleware
 * Prevents brute-force attacks on auth endpoints and API abuse.
 * Uses in-memory store (swap to Redis for production multi-instance).
 */

const rateLimit = require('express-rate-limit');

// General API rate limiter: 100 requests per minute per IP
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  message: {
    status: 'error',
    statusCode: 429,
    message: 'Too many requests. Please try again later.',
  },
  keyGenerator: (req) => {
    return req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;
  },
});

// Auth endpoints: 50 attempts per 15 minutes per IP
// (10 was too low — normal multi-user/testing scenarios hit it easily)
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === 'production' ? 50 : 200,
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  message: {
    status: 'error',
    statusCode: 429,
    message: 'Too many login attempts. Please wait 15 minutes and try again.',
  },
  keyGenerator: (req) => {
    return req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;
  },
});

// Upload endpoints: 20 uploads per minute per IP
const uploadLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  message: {
    status: 'error',
    statusCode: 429,
    message: 'Too many upload requests. Please wait before uploading again.',
  },
  keyGenerator: (req) => {
    return req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;
  },
});

// Dashboard/data endpoints: 60 requests per minute per user
const dashboardLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  validate: false,
  message: {
    status: 'error',
    statusCode: 429,
    message: 'Too many dashboard requests. Please slow down.',
  },
  keyGenerator: (req) => {
    return req.user?.id || req.headers['x-forwarded-for']?.split(',')[0]?.trim() || req.ip;
  },
});

module.exports = {
  apiLimiter,
  authLimiter,
  uploadLimiter,
  dashboardLimiter,
};
