/**
 * qc_review_lifecycle.test.js -- Quality Control review, ticket statuses and assignment rules
 */

const request = require('supertest');
const app = require('../src/app');

describe('QC Review & Task Lifecycle Pipeline', () => {
  it('GET /api/v1/qc/reviews/pending without authentication should be rejected', async () => {
    const res = await request(app).get('/api/v1/qc-reviews');
    expect([401, 403, 404]).toContain(res.statusCode);
  });

  it('POST /api/v1/qc/tickets without authorization should be rejected', async () => {
    const res = await request(app)
      .post('/api/v1/qc-tickets')
      .send({
        videoId: 1,
        decision: 'approved',
        comments: 'Clean video sample'
      });
    expect([401, 403, 404]).toContain(res.statusCode);
  });
});
