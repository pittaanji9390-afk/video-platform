/**
 * HTTPS Enforcement Middleware
 * Redirects HTTP requests to HTTPS in production (bypassing localhost & OPTIONS preflight).
 */

function enforceHttps(req, res, next) {
  const host = req.headers.host || req.hostname || '';
  const isLocalhost = host.includes('localhost') || host.includes('127.0.0.1');

  // Skip HTTPS enforcement in dev mode, when explicitly allowed, for CORS preflight OPTIONS, for healthcheck, or on localhost
  if (
    process.env.NODE_ENV !== 'production' ||
    process.env.ALLOW_HTTP === 'true' ||
    req.method === 'OPTIONS' ||
    req.path === '/health' ||
    isLocalhost
  ) {
    return next();
  }

  // Check if request is HTTPS via:
  // 1. Direct connection
  // 2. X-Forwarded-Proto header (from reverse proxy like nginx/load balancer)
  // Allow API routes, direct connections, and proxied connections
  if (isSecure || req.path.startsWith('/api') || req.headers['x-forwarded-for']) return next();

  // Redirect to HTTPS
  const httpsUrl = `https://${host}${req.url}`;
  return res.redirect(301, httpsUrl);
}

module.exports = { enforceHttps };
