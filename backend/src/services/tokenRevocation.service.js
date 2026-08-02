/**
 * Token Revocation Service
 * Blacklists revoked JWT tokens to prevent reuse after logout.
 * Uses in-memory store (swap to Redis for production multi-instance).
 */

const logger = require('../utils/logger');

// In-memory token blacklist (JWT IDs stored until expiry)
const revokedTokens = new Map();

// Cleanup interval: remove expired tokens every 10 minutes
const CLEANUP_INTERVAL = 10 * 60 * 1000;
setInterval(() => {
  const now = Date.now();
  for (const [jti, expiry] of revokedTokens) {
    if (expiry <= now) {
      revokedTokens.delete(jti);
    }
  }
}, CLEANUP_INTERVAL);

class TokenRevocation {
  /**
   * Revoke a token by its JWT ID (jti)
   * @param {string} token - The JWT token string
   * @param {number} expiresAt - Token expiry timestamp in ms
   */
  static revoke(token, expiresAt) {
    try {
      // Extract jti from token payload without verification (it's already been verified)
      const parts = token.split('.');
      if (parts.length !== 3) return false;

      let payload;
      try {
        const decoded = Buffer.from(parts[1], 'base64url').toString('utf8');
        payload = JSON.parse(decoded);
      } catch (_) {
        return false;
      }

      const jti = payload.jti || payload.sub || payload.id || token;
      const expiry = expiresAt || (payload.exp ? payload.exp * 1000 : Date.now() + 24 * 60 * 60 * 1000);

      revokedTokens.set(jti, expiry);
      logger.info(`Token revoked: ${jti}`);
      return true;
    } catch (err) {
      logger.error('Token revocation failed', { error: err.message });
      return false;
    }
  }

  /**
   * Check if a token has been revoked
   * @param {string} token - The JWT token string
   * @returns {boolean} true if revoked
   */
  static isRevoked(token) {
    try {
      const parts = token.split('.');
      if (parts.length !== 3) return false;

      let payload;
      try {
        const decoded = Buffer.from(parts[1], 'base64url').toString('utf8');
        payload = JSON.parse(decoded);
      } catch (_) {
        return false;
      }

      const jti = payload.jti || payload.sub || payload.id || token;
      return revokedTokens.has(jti);
    } catch (_) {
      return false;
    }
  }

  /**
   * Get count of revoked tokens (for monitoring)
   */
  static getRevokedCount() {
    return revokedTokens.size;
  }
}

module.exports = TokenRevocation;
