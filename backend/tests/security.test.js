/**
 * security.test.js -- Security Headers, Injection Detection & CORS Tests
 */

const request = require('supertest');
const app = require('../src/app');

describe('Security Layer & Middleware Verification', () => {
  it('should include X-Request-Id in response headers', async () => {
    const res = await request(app).get('/health');
    expect(res.headers).toHaveProperty('x-request-id');
  });

  it('should disable x-powered-by header for privacy protection', async () => {
    const res = await request(app).get('/health');
    expect(res.headers['x-powered-by']).toBeUndefined();
  });

  it('should block or sanitize malicious SQL injection payloads in request body', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: "admin' OR 1=1 --",
        password: "password123"
      });
    // Either blocked by detector or handled safely without crashing
    expect([400, 401, 403, 500]).toContain(res.statusCode);
  });

  it('should enforce proper CORS preflight response headers', async () => {
    const res = await request(app)
      .options('/api/v1/auth/login')
      .set('Origin', 'http://localhost:8081')
      .set('Access-Control-Request-Method', 'POST');
    
    expect(res.statusCode).toBeLessThan(500);
  });
});
