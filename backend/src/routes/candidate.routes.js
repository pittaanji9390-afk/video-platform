/**
 * Candidate Routes
 * Endpoints under /api/v1/candidates
 */

const express = require('express');
const router = express.Router();
const candidateController = require('../controllers/candidate.controller');
const { authenticateJWT } = require('../middleware/auth.middleware');
const { requireRole } = require('../middleware/role.middleware');
const { dashboardLimiter } = require('../middleware/rateLimiter');
const {
  validateCreateCandidate,
  validateGetCandidatesQuery,
} = require('../validators/candidate.validator');

// Apply JWT authentication middleware to protect candidate routes
router.use(authenticateJWT);

// GET /api/v1/candidates/stats - Get Candidate Counts by Status for Vendor
router.get('/stats', dashboardLimiter, requireRole('admin', 'vendor'), (req, res, next) => candidateController.getCandidateStats(req, res, next));

// POST /api/v1/candidates - Create Candidate (vendor or admin only)
router.post('/', requireRole('admin', 'vendor'), validateCreateCandidate, (req, res, next) => candidateController.createCandidate(req, res, next));

// GET /api/v1/candidates - Get All Candidates (Paginated)
router.get('/', requireRole('admin', 'vendor'), validateGetCandidatesQuery, (req, res, next) => candidateController.getCandidates(req, res, next));

module.exports = router;
