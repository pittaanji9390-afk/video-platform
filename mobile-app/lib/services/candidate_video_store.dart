import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import 'auth_service.dart';
import '../utils/web_helper.dart' as web;

class CandidateVideoStore {
  static int parseDurationSeconds(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    final str = val.toString().trim();
    if (str.isEmpty) return 0;

    final numVal = int.tryParse(str);
    if (numVal != null) return numVal;

    final cleanStr = str.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = cleanStr.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60) + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    return 0;
  }

  /// Persist newly uploaded video locally to guarantee immediate UI display
  static Future<void> saveUploadedVideo(Map<String, dynamic> video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('candidate_local_uploads');
      List<dynamic> list = [];
      if (raw != null) {
        try {
          list = jsonDecode(raw);
        } catch (_) {}
      }

      final id = video['id']?.toString() ??
          video['video_id']?.toString() ??
          'VID-${DateTime.now().millisecondsSinceEpoch}';

      // Prevent duplicate entries
      list.removeWhere((item) => (item['id']?.toString() ?? '') == id);

      list.insert(0, {
        'id': id,
        'title': video['title'] ?? '${video['env'] ?? 'Kitchen'} Video Recording',
        'env': video['environment_tag'] ?? video['env'] ?? 'Kitchen',
        'status': video['status'] ?? 'Pending QC',
        'date': video['date'] ?? 'Today, Just Now',
        'size': video['size'] ?? '10.0 MB',
        'duration': video['duration'] ?? '30:00 Mins',
        'candidateId': video['candidate_id'] ?? '',
      });

      await prefs.setString('candidate_local_uploads', jsonEncode(list));

      if (kIsWeb) {
        try {
          final bc = web.BroadcastChannelStub('platform_realtime_channel');
          bc.postMessage(jsonEncode({'type': 'VIDEO_UPLOADED', 'payload': list}));
          bc.close();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error saving local candidate video: $e');
    }
  }

  /// Unified loader for candidate uploaded videos with fallback mechanisms
  static Future<List<Map<String, dynamic>>> getUploadedVideos() async {
    final List<Map<String, dynamic>> allVideos = [];
    final Set<String> processedVideoIds = {};

    try {
      final headers = await AuthService.getAuthHeaders();
      final session = await AuthService.restoreSession();
      final currentUserId = session?['id'] ?? '';
      final currentUserEmail = session?['email'] ?? '';

      // 1. Fetch from PostgreSQL REST API
      final queryParam = currentUserId.isNotEmpty ? '?candidate_id=$currentUserId' : '';
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiVersion}/videos$queryParam');
      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);

        for (var vid in items) {
          final cId = vid['candidate_id']?.toString() ?? vid['candidateId']?.toString() ?? '';
          final cEmail = vid['email']?.toString() ?? '';

          // Candidate Scoping: verify owner matches logged-in user if specific ID provided
          if (cId.isNotEmpty && currentUserId.isNotEmpty && !currentUserId.startsWith('CAN-') && currentUserId != 'c1000000-0000-0000-0000-000000000001') {
            if (cId.toLowerCase() != currentUserId.toLowerCase()) {
              final cEmailLower = cEmail.toLowerCase();
              final curEmailLower = currentUserEmail.toLowerCase();
              if (curEmailLower.isNotEmpty && cEmailLower.isNotEmpty && cEmailLower != curEmailLower) {
                continue;
              }
            }
          }

          final id = vid['id']?.toString() ?? '';
          if (id.isNotEmpty && processedVideoIds.contains(id)) continue;
          if (id.isNotEmpty) processedVideoIds.add(id);

          final st = (vid['status'] ?? 'pending').toString().toLowerCase();
          String statusText = 'Pending QC';
          if (st == 'approved' || st == 'qc_approved') statusText = 'Approved';
          if (st.contains('reject')) statusText = 'Rejected';

          allVideos.add({
            'id': id.isNotEmpty ? id : 'VID-${allVideos.length + 1}',
            'title': vid['title'] ?? 'Dataset Video Recording',
            'env': vid['environment_tag'] ?? 'Kitchen',
            'status': statusText,
            'date': vid['recording_date'] != null ? 'Uploaded' : 'Today, Just Now',
            'size': '10.0 MB',
            'duration': vid['duration'] != null ? '${vid['duration']}s' : '30:00 Mins',
            'durationSeconds': parseDurationSeconds(vid['duration']),
            'reason': vid['rejection_reason'] ?? '',
          });
        }
      }
    } catch (_) {}

    // 2. Load from SharedPreferences local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('candidate_local_uploads');
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        for (var item in list) {
          final id = item['id']?.toString() ?? '';
          if (id.isNotEmpty && processedVideoIds.contains(id)) continue;
          if (id.isNotEmpty) processedVideoIds.add(id);

          allVideos.add({
            'id': id.isNotEmpty ? id : 'VID-${allVideos.length + 1}',
            'title': item['title'] ?? 'Uploaded Video Recording',
            'env': item['env'] ?? 'Kitchen',
            'status': item['status'] ?? 'Pending QC',
            'date': item['date'] ?? 'Today, Just Now',
            'size': item['size'] ?? '10.0 MB',
            'duration': item['duration'] ?? '30:00 Mins',
            'durationSeconds': parseDurationSeconds(item['duration']),
            'reason': item['reason'] ?? '',
          });
        }
      }
    } catch (_) {}

    // 3. Fetch from Web localStorage platform_qc_submissions
    if (kIsWeb) {
      try {
        final raw = web.localStorageGet('platform_qc_submissions');
        if (raw != null) {
          final List<dynamic> list = jsonDecode(raw);
          for (var item in list) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty && processedVideoIds.contains(id)) continue;
            if (id.isNotEmpty) processedVideoIds.add(id);

            allVideos.add({
              'id': id.isNotEmpty ? id : 'VID-${allVideos.length + 1}',
              'title': item['title'] ?? 'Uploaded Video',
              'env': item['env'] ?? 'Kitchen',
              'status': item['status'] == 'Pending' ? 'Pending QC' : (item['status'] ?? 'Approved'),
              'date': item['time'] ?? 'Just Now',
              'size': item['size'] ?? '10.0 MB',
              'duration': item['duration'] ?? '30:00 Mins',
              'durationSeconds': parseDurationSeconds(item['duration']),
              'reason': item['rejectionReason'] ?? '',
            });
          }
        }
      } catch (_) {}
    }

    return allVideos;
  }
}

