/**
 * auth_validation.test.js -- Authentication payload verification & input rules
 */

const request = require('supertest');
const app = require('../src/app');

describe('Authentication Endpoint Validation', () => {
  it('POST /api/v1/auth/login should reject empty credentials', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({});
    expect([400, 422]).toContain(res.statusCode);
  });

  it('POST /api/v1/auth/login should reject missing password', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'candidate@example.com' });
    expect([400, 422]).toContain(res.statusCode);
  });

  it('POST /api/v1/auth/login should reject invalid email format', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'invalid-email-format',
        password: 'securePassword123'
      });
    expect([400, 422]).toContain(res.statusCode);
  });
});
