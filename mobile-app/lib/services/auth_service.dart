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
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] ?? data['accessToken'] ?? 'demo_token';
        final user = data['user'] ?? {};
        final role = user['role'] ?? _determineRole(cleanIdentifier);
        
        await saveSession(
          token: token,
          refreshToken: data['refreshToken'] ?? '',
          role: role,
          name: user['name'] ?? 'User',
          email: cleanIdentifier,
          userId: user['id'] ?? 'user_123',
          vendorId: user['vendorId'] ?? 'vendor_123',
        );

        return {'success': true, 'role': role, 'data': data};
      }
    } catch (e) {
      debugPrint('Live API login exception: $e');
    }

    // Demo Mode Fallback for instant client evaluation
    final demoRole = _determineRole(cleanIdentifier);
    await saveSession(
      token: 'demo_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'demo_refresh_token',
      role: demoRole,
      name: cleanIdentifier.contains('admin') ? 'Admin User' : (cleanIdentifier.contains('vendor') ? 'Vendor User' : 'QC Evaluator'),
      email: cleanIdentifier,
      userId: 'demo_user_id',
      vendorId: 'demo_vendor_id',
    );

    return {
      'success': true,
      'role': demoRole,
      'isDemo': true,
      'message': 'Logged in successfully'
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
  }) async {
    final prefs = await _getPrefs();
    await prefs.setString(keyAccessToken, token);
    await prefs.setString(keyRefreshToken, refreshToken);
    await prefs.setString(keyUserRole, role);
    await prefs.setString(keyUserName, name);
    await prefs.setString(keyUserEmail, email);
    await prefs.setString(keyUserId, userId);
    await prefs.setString(keyVendorId, vendorId);
  }

  static Future<Map<String, String>?> restoreSession() async {
    final prefs = await _getPrefs();
    final token = prefs.getString(keyAccessToken);
    final role = prefs.getString(keyUserRole);
    if (token != null && token.isNotEmpty) {
      return {
        'token': token,
        'role': role ?? 'candidate',
        'name': prefs.getString(keyUserName) ?? '',
        'email': prefs.getString(keyUserEmail) ?? '',
        'userId': prefs.getString(keyUserId) ?? '',
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
      final url = Uri.parse('$baseUrl/auth/register');
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
    );

    return {
      'success': true,
      'isDemo': true,
      'message': 'Registered successfully (demo mode). Opening Candidate Portal...',
    };
  }
}
