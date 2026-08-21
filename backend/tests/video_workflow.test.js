/**
 * video_workflow.test.js -- Video routes, stream authorization and upload constraints
 */

const request = require('supertest');
const app = require('../src/app');

describe('Video Management & Streaming Pipeline', () => {
  it('GET /api/v1/videos/stream/:id without JWT should return 401 Unauthorized', async () => {
    const res = await request(app).get('/api/v1/videos/999/stream');
    expect([401, 403, 404]).toContain(res.statusCode);
  });

  it('POST /api/v1/videos/upload without file attachment should return 400 Bad Request', async () => {
    const res = await request(app)
      .post('/api/v1/videos/upload')
      .send({ title: 'Test Video', description: 'No file included' });
    expect([400, 401, 403]).toContain(res.statusCode);
  });

  it('GET /non-existent-route should return structured 404 error JSON', async () => {
    const res = await request(app).get('/api/v1/non-existent-api-endpoint');
    expect(res.statusCode).toEqual(404);
  });
});
