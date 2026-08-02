/**
 * Password Validation Middleware
 * Enforces strong password requirements for signup and password changes.
 */

const PASSWORD_RULES = {
  minLength: 8,
  maxLength: 128,
  requireUppercase: true,
  requireLowercase: true,
  requireNumbers: true,
  requireSpecialChar: true,
};

const COMMON_PASSWORDS = [
  'password', 'password123', 'admin', 'admin123', '123456', '12345678',
  'qwerty', 'abc123', 'letmein', 'welcome', 'monkey', 'dragon',
  'master', 'login', 'princess', 'football', 'shadow', 'sunshine',
  'trustno1', 'iloveyou', 'batman', 'access', 'hello', 'charlie',
];

function validatePassword(password) {
  const errors = [];

  if (!password || typeof password !== 'string') {
    return ['Password is required'];
  }

  const clean = password.trim();

  if (clean.length < PASSWORD_RULES.minLength) {
    errors.push(`Password must be at least ${PASSWORD_RULES.minLength} characters`);
  }
  if (clean.length > PASSWORD_RULES.maxLength) {
    errors.push(`Password must be no more than ${PASSWORD_RULES.maxLength} characters`);
  }
  if (PASSWORD_RULES.requireUppercase && !/[A-Z]/.test(clean)) {
    errors.push('Password must contain at least one uppercase letter');
  }
  if (PASSWORD_RULES.requireLowercase && !/[a-z]/.test(clean)) {
    errors.push('Password must contain at least one lowercase letter');
  }
  if (PASSWORD_RULES.requireNumbers && !/[0-9]/.test(clean)) {
    errors.push('Password must contain at least one number');
  }
  if (PASSWORD_RULES.requireSpecialChar && !/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?`~]/.test(clean)) {
    errors.push('Password must contain at least one special character');
  }
  if (COMMON_PASSWORDS.includes(clean.toLowerCase())) {
    errors.push('Password is too common. Please choose a stronger password');
  }

  // Check for sequential characters
  const sequential = /(.)\1{2,}/;
  if (sequential.test(clean)) {
    errors.push('Password should not contain repeated characters');
  }

  return errors;
}

/**
 * Express middleware for password validation on signup/password-change routes
 */
function validatePasswordMiddleware(req, res, next) {
  const { password } = req.body || {};

  const errors = validatePassword(password);
  if (errors.length > 0) {
    return res.status(400).json({
      status: 'error',
      statusCode: 400,
      message: 'Password does not meet security requirements',
      errors,
    });
  }

  next();
}

module.exports = {
  validatePassword,
  validatePasswordMiddleware,
  PASSWORD_RULES,
};
