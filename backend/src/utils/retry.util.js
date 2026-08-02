/**
 * Generic Retry Utility with Exponential Backoff
 * Retries asynchronous operations up to `maxAttempts` times.
 */
async function withRetry(fn, options = {}) {
  const maxAttempts = options.maxAttempts || 3;
  const initialDelayMs = options.delayMs || 1000;
  const backoffFactor = options.backoffFactor || 2;
  const taskName = options.taskName || 'Operation';

  let lastError;
  let currentDelay = initialDelayMs;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      console.warn(`[Retry] ${taskName} failed (Attempt ${attempt}/${maxAttempts}): ${err.message}`);

      if (attempt === maxAttempts) break;

      await new Promise((resolve) => setTimeout(resolve, currentDelay));
      currentDelay *= backoffFactor;
    }
  }

  throw lastError;
}

module.exports = {
  withRetry,
};
