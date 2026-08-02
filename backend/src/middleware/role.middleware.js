/**
 * Role-Based Access Control (RBAC) Middleware
 * Enforces role-based permissions (admin, vendor, candidate) on protected API routes
 */

/**
 * Middleware factory that restricts endpoint access to specified roles
 * @param  {...string} allowedRoles - Permitted roles (e.g. 'admin', 'vendor', 'candidate')
 */
const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    // 1. Ensure user is authenticated via JWT middleware
    if (!req.user) {
      return res.status(401).json({
        status: 'error',
        message: 'Authentication required. No user context found.',
      });
    }

    const userRole = (req.user.role || '').toLowerCase();
    const normalizedAllowedRoles = allowedRoles.map((role) => role.toLowerCase());

    // 2. Check if user role is in the list of allowed roles
    if (!userRole || !normalizedAllowedRoles.includes(userRole)) {
      return res.status(403).json({
        status: 'error',
        message: `Access denied. Insufficient permissions for role '${req.user.role || 'none'}'. Required role: [${allowedRoles.join(', ')}].`,
      });
    }

    // 3. User authorized, proceed to next handler
    next();
  };
};

module.exports = {
  requireRole,
};
