/**
 * Video Processing Service
 * Handles EXIF/GPS stripping and watermarking using ffmpeg.
 * Runs as a post-upload processing step.
 */

const { execSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const logger = require('../utils/logger');

class VideoProcessor {
  /**
   * Strip EXIF/GPS metadata from video file
   * Removes: GPS coordinates, device info, camera settings, timestamps
   * @param {string} inputPath - Path to input video
   * @returns {Object} { success, metadataRemoved }
   */
  static stripExif(inputPath) {
    const ext = path.extname(inputPath) || '.mp4';
    const tempOutput = inputPath.replace(new RegExp(`\\${ext}$`, 'i'), `_tmp${ext}`);

    try {
      // Use ffmpeg to remove all metadata while preserving video/audio streams
      execSync(
        `ffmpeg -y -i "${inputPath}" -map_metadata -1 -c:v copy -c:a copy "${tempOutput}"`,
        { timeout: 120000, stdio: 'pipe' }
      );

      // Get original metadata count for reporting
      const originalMeta = this.getMetadataCount(inputPath);

      // Replace original with cleaned version
      fs.renameSync(tempOutput, inputPath);

      logger.info('EXIF/GPS metadata stripped from video', {
        file: path.basename(inputPath),
        metadataRemoved: originalMeta,
      });

      return { success: true, metadataRemoved: originalMeta };
    } catch (error) {
      // Clean up temp file on failure
      if (fs.existsSync(tempOutput)) {
        fs.unlinkSync(tempOutput);
      }

      logger.error('EXIF stripping failed', {
        file: path.basename(inputPath),
        error: error.message,
      });

      return { success: false, error: error.message };
    }
  }

  /**
   * Add visible watermark to video
   * @param {string} inputPath - Path to input video
   * @param {string} watermarkText - Text to display (e.g., vendor ID, timestamp)
   * @param {Object} options - Watermark options
   * @returns {Object} { success, outputPath }
   */
  static addWatermark(inputPath, watermarkText, options = {}) {
    const {
      position = 'bottom-right',   // top-left, top-right, bottom-left, bottom-right
      fontSize = 24,
      fontColor = 'white',
      bgColor = 'black@0.5',       // semi-transparent black background
      margin = 20,
    } = options;

    const ext = path.extname(inputPath) || '.mp4';
    const outputPath = inputPath.replace(new RegExp(`\\${ext}$`, 'i'), `_watermarked${ext}`);
    const tempOutput = outputPath.replace(new RegExp(`\\${ext}$`, 'i'), `_tmp${ext}`);

    try {
      // Build position filter based on options
      let positionFilter;
      switch (position) {
        case 'top-left':
          positionFilter = `x=${margin}:y=${margin}`;
          break;
        case 'top-right':
          positionFilter = `x=w-tw-${margin}:y=${margin}`;
          break;
        case 'bottom-left':
          positionFilter = `x=${margin}:y=h-th-${margin}`;
          break;
        case 'bottom-right':
        default:
          positionFilter = `x=w-tw-${margin}:y=h-th-${margin}`;
          break;
      }

      // Build drawtext filter for watermark
      const drawtextFilter = `drawtext=text='${watermarkText.replace(/'/g, "\\'")}':fontsize=${fontSize}:fontcolor=${fontColor}:box=1:boxcolor=${bgColor}:boxborderw=5:${positionFilter}`;

      // Apply watermark using ffmpeg
      execSync(
        `ffmpeg -y -i "${inputPath}" -vf "${drawtextFilter}" -c:a copy "${tempOutput}"`,
        { timeout: 120000, stdio: 'pipe' }
      );

      // Replace original with watermarked version
      fs.renameSync(tempOutput, outputPath);

      // If output is different from input, clean up original
      if (outputPath !== inputPath) {
        fs.unlinkSync(inputPath);
      }

      logger.info('Watermark added to video', {
        file: path.basename(outputPath),
        text: watermarkText,
        position,
      });

      return { success: true, outputPath };
    } catch (error) {
      // Clean up temp file on failure
      if (fs.existsSync(tempOutput)) {
        fs.unlinkSync(tempOutput);
      }

      logger.error('Watermarking failed', {
        file: path.basename(inputPath),
        error: error.message,
      });

      return { success: false, error: error.message };
    }
  }

  /**
   * Process video: strip EXIF + add watermark
   * @param {string} inputPath - Path to input video
   * @param {Object} metadata - Video metadata for watermark
   * @returns {Object} { success, exifResult, watermarkResult, finalPath }
   */
  static async processVideo(inputPath, metadata = {}) {
    const { vendorId, candidateId, videoId } = metadata;

    // Step 1: Strip EXIF/GPS data
    const exifResult = this.stripExif(inputPath);

    // Step 2: Add watermark if vendor/candidate info available
    let watermarkResult = { success: true, skipped: true };
    if (vendorId || candidateId) {
      const watermarkText = `ID:${videoId || 'N/A'} V:${vendorId || 'N/A'} C:${candidateId || 'N/A'}`;
      watermarkResult = this.addWatermark(inputPath, watermarkText, {
        position: 'bottom-right',
        fontSize: 18,
        fontColor: 'white',
        bgColor: 'black@0.5',
        margin: 15,
      });
    }

    return {
      success: exifResult.success && watermarkResult.success,
      exifResult,
      watermarkResult,
      finalPath: watermarkResult.outputPath || inputPath,
    };
  }

  /**
   * Get metadata count from video file (for reporting)
   * @param {string} filePath - Path to video file
   * @returns {number} Number of metadata entries
   */
  static getMetadataCount(filePath) {
    try {
      const output = execSync(
        `ffprobe -v quiet -print_format json -show_format "${filePath}"`,
        { timeout: 10000, stdio: 'pipe' }
      ).toString();

      const probe = JSON.parse(output);
      const tags = probe.format?.tags || {};
      return Object.keys(tags).length;
    } catch {
      return 0;
    }
  }

  /**
   * Check if ffmpeg is available
   * @returns {boolean}
   */
  static isAvailable() {
    try {
      execSync('ffmpeg -version', { stdio: 'ignore' });
      return true;
    } catch {
      return false;
    }
  }
}

module.exports = VideoProcessor;
