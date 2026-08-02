/**
 * Candidate Controller
 */

const candidateService = require('../services/candidate.service');

class CandidateController {
  /**
   * POST /api/v1/candidates
   */
  async createCandidate(req, res, next) {
    try {
      const { vendor_id, full_name, phone, email } = req.body;

      const newCandidate = await candidateService.createCandidate({
        vendor_id,
        full_name,
        phone,
        email,
      });

      return res.status(201).json({
        status: 'success',
        message: 'Candidate created successfully',
        data: newCandidate,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/candidates
   */
  async getCandidates(req, res, next) {
    try {
      const { vendor_id, page, limit } = req.query;

      const result = await candidateService.getCandidates({
        vendor_id,
        page,
        limit,
      });

      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/candidates/stats
   */
  async getCandidateStats(req, res, next) {
    try {
      const { vendor_id } = req.query;
      const stats = await candidateService.getCandidateStats({ vendor_id });

      return res.status(200).json({
        status: 'success',
        message: 'Candidate status counts fetched successfully',
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CandidateController();
