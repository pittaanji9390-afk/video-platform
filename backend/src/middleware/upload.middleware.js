/**
 * Video File Upload Middleware (Multer)
 * 
 * Handles single MP4 video file uploads up to 500MB.
 * Stores files locally in backend/uploads/videos/.
 */

const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Ensure destination upload directory exists
const uploadDir = path.join(__dirname, '../../uploads/videos');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

// Multer disk storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = crypto.randomUUID();
    const ext = path.extname(file.originalname).toLowerCase() || '.mp4';
    cb(null, `video-${uniqueSuffix}${ext}`);
  },
});

// File filter - enforce MP4 format only
const fileFilter = (req, file, cb) => {
  const isMp4Mime = file.mimetype === 'video/mp4';
  const isMp4Ext = path.extname(file.originalname).toLowerCase() === '.mp4';

  if (isMp4Mime && isMp4Ext) {
    return cb(null, true);
  }
  const error = new Error('Invalid file format. Only MP4 video files are allowed');
  error.statusCode = 400;
  return cb(error, false);
};

// Multer upload instance with 500MB size limit
const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 500 * 1024 * 1024, // 500 MB
  },
}).single('video');

// Express middleware wrapper to handle Multer errors cleanly
function uploadVideoMiddleware(req, res, next) {
  upload(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(400).json({
          status: 'error',
          statusCode: 400,
          message: 'File size exceeds maximum limit of 500 MB',
        });
      }
      return res.status(400).json({
        status: 'error',
        statusCode: 400,
        message: err.message,
      });
    } else if (err) {
      return res.status(err.statusCode || 400).json({
        status: 'error',
        statusCode: err.statusCode || 400,
        message: err.message,
      });
    }

    if (!req.file) {
      return res.status(400).json({
        status: 'error',
        statusCode: 400,
        message: 'No video file provided in request field "video"',
      });
    }

    next();
  });
}

module.exports = uploadVideoMiddleware;
