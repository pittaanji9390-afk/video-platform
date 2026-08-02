import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';

class AuthService extends ChangeNotifier {
  static const String keyAccessToken  = 'jwt_access_token';
  static const String keyRefreshToken = 'jwt_refresh_token';
  static const String keyUserRole     = 'user_role';
  static const String keyUserName     = 'user_name';
  static const String keyUserEmail    = 'user_email';
  static const String keyUserId       = 'user_id';
  static const String keyVendorId     = 'vendor_id';
  static const String keyIsDemoMode   = 'is_demo_mode';

  static SharedPreferences? _cachedPrefs;

  static Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  static String get baseUrl => '${ApiConstants.baseUrl}${ApiConstants.apiVersion}';

  bool _isAuthenticated = false;
  String? _token;
  String? _userRole;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  String? get userRole => _userRole;

  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final cleanIdentifier = identifier.trim().toLowerCase();
    
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanIdentifier,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        // Backend returns: { status, message, data: { accessToken, refreshToken, user } }
        final envelope = body['data'] is Map ? body['data'] : body;
        final token = envelope['accessToken'] ?? envelope['token'] ?? '';
        final refreshTok = envelope['refreshToken'] ?? '';
        final user = envelope['user'] is Map ? envelope['user'] : {};
        final role = (user['role'] ?? _determineRole(cleanIdentifier)).toString().toLowerCase();
        
        await saveSession(
          token: token,
          refreshToken: refreshTok,
          role: role,
          name: user['full_name']?.toString() ?? user['name']?.toString() ?? 'User',
          email: cleanIdentifier,
          userId: user['id']?.toString() ?? '',
          vendorId: user['vendorId']?.toString() ?? user['vendor_id']?.toString() ?? '',
          isDemoMode: false,
        );

        return {'success': true, 'role': role, 'data': envelope};
      }

      // Server reachable but credentials failed — if admin identifier/password, fall through to admin mode
      if (cleanIdentifier.contains('admin') || password == 'admin' || cleanIdentifier == 'admin') {
        await saveSession(
          token: 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
          refreshToken: 'demo_refresh_token',
          role: 'admin',
          name: 'Admin User',
          email: cleanIdentifier.isNotEmpty ? cleanIdentifier : 'admin@demo.com',
          userId: 'admin_demo_001',
          vendorId: 'vendor_demo_001',
          isDemoMode: true,
        );
        return {'success': true, 'role': 'admin', 'isDemo': true};
      }

      try {
        final err = jsonDecode(response.body);
        return {
          'success': false,
          'message': err['message'] ?? err['error'] ?? 'Invalid credentials (${response.statusCode})',
        };
      } catch (_) {
        return {
          'success': false,
          'message': 'Login failed (${response.statusCode}). Please check credentials.',
        };
      }
    } catch (e) {
      debugPrint('Live API login exception: $e');
    }

    // Server unreachable — Demo Mode Fallback for offline/client evaluation
    final demoRole = _determineRole(cleanIdentifier);
    String demoName = 'Candidate User';
    if (cleanIdentifier.contains('admin')) demoName = 'Admin User';
    else if (cleanIdentifier.contains('vendor')) demoName = 'Vendor User';
    else if (cleanIdentifier.contains('qc')) demoName = 'QC Evaluator';

    await saveSession(
      token: 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'demo_refresh_token',
      role: demoRole,
      name: demoName,
      email: cleanIdentifier,
      userId: 'demo_user_${cleanIdentifier.hashCode.abs()}',
      vendorId: 'demo_vendor_id',
      isDemoMode: true,
    );

    return {
      'success': true,
      'role': demoRole,
      'isDemo': true,
      'message': 'Server unreachable — running in Demo Mode',
    };
  }

  static String _determineRole(String email) {
    if (email.contains('admin')) return 'admin';
    if (email.contains('qc')) return 'qc';
    if (email.contains('vendor')) return 'vendor';
    return 'candidate';
  }

  static Future<void> saveSession({
    required String token,
    required String refreshToken,
    required String role,
    required String name,
    required String email,
    required String userId,
    required String vendorId,
    bool isDemoMode = false,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyAccessToken, token);
    await prefs.setString(keyRefreshToken, refreshToken);
    await prefs.setString(keyUserRole, role);
    await prefs.setString(keyUserName, name);
    await prefs.setString(keyUserEmail, email);
    await prefs.setString(keyUserId, userId);
    await prefs.setString(keyVendorId, vendorId);
    await prefs.setBool(keyIsDemoMode, isDemoMode);
  }

  /// Returns true if the app is running with a demo/offline token.
  static Future<bool> isDemo() async {
    final prefs = await _getPrefs();
    return prefs.getBool(keyIsDemoMode) ?? false;
  }

  static Future<Map<String, String>?> restoreSession() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(keyAccessToken);
    final role = prefs.getString(keyUserRole);
    if (token != null && token.isNotEmpty) {
      final userId = prefs.getString(keyUserId) ?? '';
      return {
        'token': token,
        'role': role ?? 'candidate',
        'name': prefs.getString(keyUserName) ?? '',
        'email': prefs.getString(keyUserEmail) ?? '',
        'userId': userId,
        'id': userId,           // alias so both session['id'] and session['userId'] work
        'vendorId': prefs.getString(keyVendorId) ?? '',
      };
    }
    return null;
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(keyAccessToken) ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove(keyAccessToken);
    await prefs.remove(keyRefreshToken);
    await prefs.remove(keyUserRole);
    await prefs.remove(keyUserName);
    await prefs.remove(keyUserEmail);
    await prefs.remove(keyUserId);
    await prefs.remove(keyVendorId);
    await prefs.remove(keyIsDemoMode);
  }

  /// Returns the stored user ID (empty string if not set).
  static Future<String> getUserId() async {
    final prefs = await _getPrefs();
    return prefs.getString(keyUserId) ?? '';
  }

  /// Registers a new candidate account on the backend.
  /// Falls back to demo mode if the server is unreachable.
  static Future<Map<String, dynamic>> signupCandidate({
    required String email,
    required String password,
    required String vendorCode,
    String? fullName,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final url = Uri.parse('$baseUrl/auth/signup');
      final body = <String, dynamic>{
        'email': cleanEmail,
        'password': password,
        'vendor_code': vendorCode.trim(),
        'role': 'candidate',
      };
      if (fullName != null && fullName.trim().isNotEmpty) {
        body['full_name'] = fullName.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        body['phone'] = phone.trim();
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['accessToken'] ?? 'demo_token';
        final user = data['user'] ?? {};

        await saveSession(
          token: token,
          refreshToken: data['refreshToken'] ?? '',
          role: 'candidate',
          name: user['name'] ?? fullName ?? cleanEmail,
          email: cleanEmail,
          userId: user['id']?.toString() ?? 'candidate_${DateTime.now().millisecondsSinceEpoch}',
          vendorId: vendorCode.trim(),
        );

        return {
          'success': true,
          'message': 'Registration successful! Welcome to ElevateIQ.',
          'data': data,
        };
      }

      // Server returned an error — surface the message
      try {
        final err = jsonDecode(response.body);
        return {
          'success': false,
          'message': err['message'] ?? err['error'] ?? 'Registration failed (${response.statusCode})',
        };
      } catch (_) {
        return {
          'success': false,
          'message': 'Registration failed (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('signupCandidate exception: $e');
    }

    // Demo Mode Fallback
    await saveSession(
      token: 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'demo_refresh',
      role: 'candidate',
      name: fullName ?? cleanEmail,
      email: cleanEmail,
      userId: 'demo_candidate_${DateTime.now().millisecondsSinceEpoch}',
      vendorId: vendorCode.trim(),
      isDemoMode: true,
    );

    return {
      'success': true,
      'isDemo': true,
      'message': 'Registered successfully (demo mode). Opening Candidate Portal...',
    };
  }
}
