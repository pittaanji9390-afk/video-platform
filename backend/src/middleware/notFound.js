/**
 * Not Found (404) Middleware
 * 
 * Catches all requests that don't match any defined route.
 * Returns a JSON response with the attempted URL path.
 * 
 * Must be registered AFTER all routes but BEFORE the error handler.
 */

function notFound(req, res, next) {
  const error = new Error(`Not Found - ${req.originalUrl}`);
  error.statusCode = 404;
  next(error);
}

module.exports = notFound;
