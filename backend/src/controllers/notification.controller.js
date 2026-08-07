/**
 * Notification Controller
 * Handles SSE Real-Time Notification Stream, Read-Once Updates, and Real Event Retrieval
 */

const notificationService = require('../services/notification.service');

class NotificationController {
  /**
   * SSE Stream Endpoint: GET /api/v1/notifications/stream
   */
  async subscribeStream(req, res) {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    const sseOrigin = process.env.CORS_ORIGIN || 'http://localhost:8081';
    res.setHeader('Access-Control-Allow-Origin', sseOrigin);
    res.flushHeaders();

    // Register client for targeted real-time notification push
    const userId = req.user?.id || req.query?.user_id || req.query?.userId;
    const role = req.user?.role || req.query?.role;
    notificationService.registerSSEClient(res, userId, role);

    // Send initial ping
    res.write('data: {"type": "connected"}\n\n');
  }

  async getNotifications(req, res, next) {
    try {
      const userId = req.user?.id || null;
      const role = req.user?.role || 'candidate';

      const result = await notificationService.getNotifications({ user_id: userId, role });
      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async markSingleRead(req, res, next) {
    try {
      const { id } = req.params;
      await notificationService.markSingleRead(id);

      const userId = req.user?.id || null;
      const role = req.user?.role || 'candidate';
      const result = await notificationService.getNotifications({ user_id: userId, role });

      return res.status(200).json({
        status: 'success',
        message: 'Notification marked as read',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async markAllRead(req, res, next) {
    try {
      const userId = req.user?.id || null;
      const role = req.user?.role || 'candidate';

      await notificationService.markAllRead(userId, role);
      const result = await notificationService.getNotifications({ user_id: userId, role });

      return res.status(200).json({
        status: 'success',
        message: 'All notifications marked as read',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async createNotification(req, res, next) {
    try {
      const notification = await notificationService.createNotification(req.body);
      return res.status(201).json({
        status: 'success',
        message: 'Real-time notification generated',
        data: { notification },
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new NotificationController();
