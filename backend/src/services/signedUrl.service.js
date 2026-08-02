/**
 * Signed URL Service
 * Generates time-limited signed URLs for secure video file access.
 * Tokens expire after a configurable time (default: 60 minutes).
 */

const crypto = require('crypto');
const logger = require('../utils/logger');

const SECRET = process.env.JWT_SECRET || 'fallback-signing-key';
const EXPIRY_MS = 60 * 60 * 1000; // 60 minutes

class SignedUrlService {
  /**
   * Generate a signed token for video access
   * @param {string} videoId - The video ID
   * @param {string} userId - The user requesting access
   * @param {string} action - The action (stream, download)
   * @returns {Object} { token, expiresAt }
   */
  static generate(videoId, userId, action = 'stream') {
    const expiresAt = Date.now() + EXPIRY_MS;
    const payload = `${videoId}:${userId}:${action}:${expiresAt}`;
    const signature = crypto
      .createHmac('sha256', SECRET)
      .update(payload)
      .digest('hex');

    return {
      token: `${Buffer.from(payload).toString('base64')}.${signature}`,
      expiresAt: new Date(expiresAt).toISOString(),
    };
  }

  /**
   * Verify a signed token
   * @param {string} token - The signed token
   * @param {string} videoId - Expected video ID
   * @param {string} userId - Expected user ID
   * @param {string} action - Expected action
   * @returns {Object|null} { valid, expired, payload }
   */
  static verify(token, videoId, userId, action = 'stream') {
    try {
      const [payloadB64, signature] = token.split('.');
      if (!payloadB64 || !signature) return { valid: false, expired: false };

      const payload = Buffer.from(payloadB64, 'base64').toString('utf8');
      const [tVideoId, tUserId, tAction, tExpiresAt] = payload.split(':');

      // Verify HMAC signature
      const expectedSignature = crypto
        .createHmac('sha256', SECRET)
        .update(payload)
        .digest('hex');

      if (signature !== expectedSignature) {
        logger.warn('Invalid signed URL signature', { videoId, userId });
        return { valid: false, expired: false };
      }

      // Check expiry
      if (Date.now() > parseInt(tExpiresAt, 10)) {
        return { valid: false, expired: true };
      }

      // Verify claims match
      if (tVideoId !== videoId || tUserId !== userId || tAction !== action) {
        return { valid: false, expired: false };
      }

      return { valid: true, expired: false, payload: { videoId, userId, action } };
    } catch (error) {
      logger.warn('Signed URL verification failed', { error: error.message });
      return { valid: false, expired: false };
    }
  }
}

module.exports = SignedUrlService;
