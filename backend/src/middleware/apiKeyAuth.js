/**
 * API Key Authentication Middleware
 * Optional API key auth for external integrations and service-to-service calls.
 * 
 * Usage: Set API_KEYS env var as comma-separated keys.
 *        Send key via X-API-Key header.
 */

const config = require('../config');

/**
 * Middleware to authenticate requests using API keys.
 * Checks X-API-Key header against configured valid keys.
 */
function authenticateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'];

  if (!apiKey) {
    return res.status(401).json({
      status: 'error',
      statusCode: 401,
      message: 'API key required. Provide via X-API-Key header.',
    });
  }

  const validKeys = (process.env.API_KEYS || '').split(',').map(k => k.trim()).filter(Boolean);

  if (validKeys.length === 0) {
    return res.status(500).json({
      status: 'error',
      statusCode: 500,
      message: 'API key authentication not configured on server.',
    });
  }

  if (!validKeys.includes(apiKey)) {
    return res.status(403).json({
      status: 'error',
      statusCode: 403,
      message: 'Invalid API key.',
    });
  }

  // Set a generic service identity for API key-authenticated requests
  req.user = req.user || {
    id: null,
    email: 'api-key-auth',
    name: 'External Service',
    role: 'admin',
  };

  next();
}

module.exports = { authenticateApiKey };
