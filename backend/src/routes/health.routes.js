const express = require('express');
const router = express.Router();
const db = require('../database/connection');

// GET /health
router.get('/', async (req, res) => {
  const isDbConnected = await db.checkConnection();

  if (isDbConnected) {
    return res.status(200).json({
      status: 'ok',
      database: 'connected',
    });
  }

  return res.status(500).json({
    status: 'error',
    database: 'disconnected',
  });
});

module.exports = router;
