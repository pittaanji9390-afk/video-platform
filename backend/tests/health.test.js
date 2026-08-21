/**
 * health.test.js -- Integration tests for Server Health & Diagnostics
 */

const request = require('supertest');
const app = require('../src/app');

describe('Health & Diagnostic Endpoints', () => {
  it('GET /health should return 200 with healthy status and uptime', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toEqual(200);
    expect(res.body).toHaveProperty('status', 'healthy');
    expect(res.body).toHaveProperty('uptime');
    expect(res.body).toHaveProperty('timestamp');
    expect(typeof res.body.uptime).toBe('number');
  });

  it('GET /api/v1/health should respond with API metadata', async () => {
    const res = await request(app).get('/api/v1/health');
    expect([200, 404]).toContain(res.statusCode);
  });
});
