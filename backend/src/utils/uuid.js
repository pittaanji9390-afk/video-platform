/**
 * UUID Validation Utility
 * Validates standard 8-4-4-4-12 hexadecimal string format for UUIDs.
 */

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function isValidUUID(uuid) {
  return typeof uuid === 'string' && UUID_REGEX.test(uuid.trim());
}

module.exports = {
  isValidUUID,
};
