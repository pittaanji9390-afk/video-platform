/**
 * Environment Variable Validator
 * 
 * Validates that all required environment variables are present before
 * the server starts. If any required variable is missing, the process
 * exits with a clear error message.
 * 
 * This runs BEFORE any other module loads to catch config issues early.
 */

const requiredEnvVars = [
  'JWT_SECRET',
  'JWT_REFRESH_SECRET',
];

function validateEnv() {
  const missing = [];

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar] || process.env[envVar].trim() === '') {
      missing.push(envVar);
    }
  }

  if (missing.length > 0) {
    console.error('\n✗ Missing required environment variables:\n');
    missing.forEach((varName) => {
      console.error(`  - ${varName}`);
    });
    console.error('\nPlease check your .env file and ensure all variables are set.');
    console.error('Refer to .env.example for the required format.\n');
    process.exit(1);
  }

  console.log('✓ All environment variables validated');
}

module.exports = validateEnv;
