import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';

class VideoPlaybackDialog extends StatefulWidget {
  final Map<String, dynamic> videoData;

  const VideoPlaybackDialog({super.key, required this.videoData});

  static void show(BuildContext context, Map<String, dynamic> videoData) {
    showDialog(
      context: context,
      builder: (ctx) => VideoPlaybackDialog(videoData: videoData),
    );
  }

  @override
  State<VideoPlaybackDialog> createState() => _VideoPlaybackDialogState();
}

class _VideoPlaybackDialogState extends State<VideoPlaybackDialog> {
  bool _isPlaying = false;

  String _resolveStreamUrl() {
    final v = widget.videoData;
    final id = v['video_id'] ?? v['id'] ?? v['raw_id'] ?? '';
    if (id.toString().isNotEmpty && !id.toString().startsWith('VID-') && !id.toString().startsWith('TKT-')) {
      return '${ApiConstants.baseUrl}${ApiConstants.apiVersion}/videos/$id/stream';
    }

    final s3Url = v['s3_url'] ?? v['url'] ?? v['s3Url'] ?? '';
    if (s3Url.toString().startsWith('http')) return s3Url.toString();

    final localPath = v['local_path'] ?? v['path'] ?? '';
    if (localPath.toString().isNotEmpty) {
      final cleanPath = localPath.toString().replaceAll(RegExp(r'^\.?\/+'), '');
      return '${ApiConstants.baseUrl}/$cleanPath';
    }

    return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.videoData;
    final title = v['title'] ?? v['video_title'] ?? 'Dataset Video Recording';
    final env = v['env'] ?? v['environment_tag'] ?? 'Kitchen';
    final candidateName = v['candidate_name'] ?? v['candidate'] ?? 'Candidate';
    final vendorName = v['vendor_name'] ?? v['vendor'] ?? 'Vendor';
    final status = v['status'] ?? 'Pending QC';
    final duration = v['duration'] ?? '0:15';
    final reason = v['reason'] ?? v['rejection_reason'] ?? '';
    final streamUrl = _resolveStreamUrl();

    final isApproved = status.toString().toLowerCase().contains('approv');
    final isRejected = status.toString().toLowerCase().contains('reject');

    Color statusColor = const Color(0xFFD97706);
    Color statusBg = const Color(0xFFFEF3C7);
    if (isApproved) {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
    } else if (isRejected) {
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
    }

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_collection_rounded, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Video Player Viewport Container
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Video Backdrop / Thumbnail
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isPlaying ? Icons.graphic_eq_rounded : Icons.videocam_rounded,
                              size: 48,
                              color: const Color(0xFF38BDF8).withAlpha(200),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isPlaying ? 'Streaming Video Player...' : 'Tap Play to Watch Recording',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Big Play Button Overlay
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isPlaying = !_isPlaying;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _isPlaying
                              ? const Color(0xFF0284C7).withAlpha(200)
                              : const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withAlpha(100),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),

                    // Top Left Environment Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          'ENV: $env',
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Top Right Duration Badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(180),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          duration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Bottom Player Controls Bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withAlpha(220)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isPlaying = !_isPlaying),
                            ),
                            const Expanded(
                              child: LinearProgressIndicator(
                                value: 0.45,
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '00:07 / 00:15',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video Details Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'URL: ${streamUrl.substring(0, streamUrl.length > 35 ? 35 : streamUrl.length)}...',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(Icons.person_rounded, color: Color(0xFF94A3B8), size: 16),
                      const SizedBox(width: 6),
                      Text('Candidate: $candidateName', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.business_rounded, color: Color(0xFF94A3B8), size: 16),
                      const SizedBox(width: 6),
                      Text('Vendor: $vendorName', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                    ],
                  ),

                  if (reason.toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF450A0A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF991B1B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rejection Feedback: $reason',
                              style: const TextStyle(color: Color(0xFFFECDD3), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
