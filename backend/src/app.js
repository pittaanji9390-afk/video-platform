const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const crypto = require('crypto');
const routes = require('./routes');
const notFound = require('./middleware/notFound');
const errorHandler = require('./middleware/errorHandler');
const { apiLimiter } = require('./middleware/rateLimiter');
const { sanitizeInput, detectSQLInjection, requestId } = require('./middleware/sanitize');
const { enforceHttps } = require('./middleware/enforceHttps');

const app = express();

// Security Layer 1: Request ID & HTTPS Enforcement
app.use(requestId);
app.use(enforceHttps);

// In-App Auto-Update Version Check Endpoint
app.get('/api/v1/app/version', (req, res) => {
  res.json({
    latestVersion: '1.0.0',
    apkUrl: 'https://github.com/rohith1246/video-platform/releases',
    forceUpdate: false,
    releaseNotes: 'Performance improvements and bug fixes.'
  });
});

// ============================================================================
// SECURITY LAYER 2: Security Headers (Helmet)
// ============================================================================
app.disable('x-powered-by');
app.set('etag', 'strong');
app.use(helmet({
  crossOriginResourcePolicy: { policy: "same-origin" },
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "blob:"],
      mediaSrc: ["'self'", "blob:", "data:"],
      connectSrc: ["'self'"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
}));

// ============================================================================
// SECURITY LAYER 3: CORS Configuration
// ============================================================================
const allowedOrigins = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map(o => o.trim())
  : ['http://localhost:8081', 'http://localhost:5000', 'http://127.0.0.1:8081', 'http://127.0.0.1:5000'];

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);
    if (allowedOrigins.includes('*') || allowedOrigins.includes(origin) || origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
      return callback(null, true);
    }
    return callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id', 'X-API-Key'],
  exposedHeaders: ['X-Request-Id', 'X-RateLimit-Limit', 'X-RateLimit-Remaining'],
  credentials: true,
  maxAge: 86400,
}));

// ============================================================================
// SECURITY LAYER 4: Rate Limiting
// ============================================================================
app.use('/api/', apiLimiter);

// ============================================================================
// SECURITY LAYER 5: Input Sanitization & Injection Detection
// ============================================================================
app.use(sanitizeInput);
app.use(detectSQLInjection);

// ============================================================================
// SECURITY LAYER 6: Request Logging
// ============================================================================
morgan.token('request-id', (req) => req.id || req.headers['x-request-id'] || '-');

app.use(morgan(':method :url :status :res[content-length] - :response-time ms [:request-id]', {
  skip: (req) => req.url === '/health',
  stream: {
    write: (message) => {
      process.stdout.write(message);
    },
  },
}));

// ============================================================================
// SECURITY LAYER 7: Body Parsing with Limits
// ============================================================================
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));

// ============================================================================
// SECURITY LAYER 8: Static File Security
// FIX #1: Videos NO LONGER served via unauthenticated static path.
// Use /api/v1/videos/:id/stream with JWT auth instead.
// Only serve non-sensitive static assets (e.g., app icons, documents).
// ============================================================================
app.use('/uploads', express.static(path.join(__dirname, '../uploads'), {
  setHeaders: (res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('X-Frame-Options', 'DENY');
  },
}));

// Serve pre-compiled Flutter Mobile App
app.use('/app', express.static(path.join(__dirname, '../../mobile-app/build/web')));

// ============================================================================
// SECURITY LAYER 9: Health Check (no auth, no rate limit)
// ============================================================================
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
  });
});

// ============================================================================
// SECURITY LAYER 10: Route Mounting
// ============================================================================
app.use('/', routes);

// ============================================================================
// SECURITY LAYER 11: Error Handling
// ============================================================================
app.use(notFound);
app.use(errorHandler);

module.exports = app;
