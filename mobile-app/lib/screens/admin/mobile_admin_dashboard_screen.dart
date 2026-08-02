import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../config/routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/powered_by_footer.dart';
import '../../utils/web_helper.dart' as web;

class MobileAdminDashboardScreen extends StatefulWidget {
  const MobileAdminDashboardScreen({super.key});

  @override
  State<MobileAdminDashboardScreen> createState() => _MobileAdminDashboardScreenState();
}

class _MobileAdminDashboardScreenState extends State<MobileAdminDashboardScreen> {
  int _activeNavIndex = 0;
  bool _isLoading = false;
  bool _isFetching = false;
  String _selectedTimeframe = 'This Week';

  // Metrics
  int _totalVendorsCount = 0;
  int _totalCandidatesCount = 0;
  int _totalVideosCount = 0;
  int _pendingQCCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  // Data lists
  final List<Map<String, dynamic>> _vendors = [];
  final List<Map<String, dynamic>> _candidates = [];
  final List<Map<String, dynamic>> _qcSubmissions = [];
  final List<Map<String, dynamic>> _activities = [];
  final List<Map<String, dynamic>> _dailyTrends = [];

  // Controllers for Add Vendor
  final _vendorNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _vendorEmailCtrl = TextEditingController();
  final _vendorPhoneCtrl = TextEditingController();
  final _vendorPasswordCtrl = TextEditingController();
  bool _obscureVendorPassword = true;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  @override
  void dispose() {
    _vendorNameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _vendorEmailCtrl.dispose();
    _vendorPhoneCtrl.dispose();
    _vendorPasswordCtrl.dispose();
    super.dispose();
  }

  String get _apiBaseUrl => '${ApiConstants.baseUrl}${ApiConstants.apiVersion}';

  Future<void> _initDashboard() async {
    final session = await AuthService.restoreSession();
    if (session == null || session['token'] == null || session['token']!.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
      return;
    }
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted || _isFetching) return;
    _isFetching = true;
    setState(() => _isLoading = true);

    try {
      final headers = await AuthService.getAuthHeaders();

      // Fetch 5 API endpoints in parallel safely
      final results = await Future.wait([
        http.get(Uri.parse('$_apiBaseUrl/admins/dashboard-stats'), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_apiBaseUrl/vendors'), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_apiBaseUrl/candidates'), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_apiBaseUrl/videos'), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
        http.get(Uri.parse('$_apiBaseUrl/notifications?role=admin'), headers: headers).timeout(const Duration(seconds: 4)).catchError((_) => http.Response('', 500)),
      ]);

      int tempVendorsCount = 0;
      int tempCandidatesCount = 0;
      int tempVideosCount = 0;
      int tempPendingQC = 0;
      int tempApproved = 0;
      int tempRejected = 0;

      final List<Map<String, dynamic>> tempTrends = [];
      final List<Map<String, dynamic>> tempVendors = [];
      final List<Map<String, dynamic>> tempCandidates = [];
      final List<Map<String, dynamic>> tempQC = [];
      final List<Map<String, dynamic>> tempNotifs = [];

      // 1. Stats
      if (results[0].statusCode == 200) {
        try {
          final body = jsonDecode(results[0].body);
          final s = body['data'] ?? {};
          tempVendorsCount = num.tryParse(s['total_vendors']?.toString() ?? '0')?.toInt() ?? 0;
          tempCandidatesCount = num.tryParse(s['total_candidates']?.toString() ?? '0')?.toInt() ?? 0;
          tempVideosCount = num.tryParse(s['total_uploaded_videos']?.toString() ?? '0')?.toInt() ?? 0;
          tempPendingQC = num.tryParse(s['pending_qc']?.toString() ?? '0')?.toInt() ?? 0;
          tempApproved = num.tryParse(s['approved']?.toString() ?? '0')?.toInt() ?? 0;
          tempRejected = num.tryParse(s['rejected']?.toString() ?? '0')?.toInt() ?? 0;

          if (s['daily_trends'] is List) {
            for (var t in s['daily_trends']) {
              tempTrends.add({
                'day': t['day']?.toString() ?? 'Day',
                'uploaded': num.tryParse(t['uploaded']?.toString() ?? '0')?.toInt() ?? 0,
                'approved': num.tryParse(t['approved']?.toString() ?? '0')?.toInt() ?? 0,
                'rejected': num.tryParse(t['rejected']?.toString() ?? '0')?.toInt() ?? 0,
              });
            }
          }
        } catch (_) {}
      }

      // 2. Vendors
      if (results[1].statusCode == 200) {
        try {
          final body = jsonDecode(results[1].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          for (var v in items) {
            tempVendors.add({
              'id': v['id']?.toString() ?? 'VEN-001',
              'vendor_code': v['vendor_code']?.toString() ?? 'VEN-001',
              'name': v['name']?.toString() ?? v['company_name']?.toString() ?? 'Vendor Company',
              'contact': v['contact_person']?.toString() ?? 'Contact Person',
              'email': v['email']?.toString() ?? 'vendor@example.com',
              'phone': v['phone']?.toString() ?? 'N/A',
              'candidates': num.tryParse(v['candidates']?.toString() ?? '0')?.toInt() ?? 0,
              'videos': num.tryParse(v['videos']?.toString() ?? '0')?.toInt() ?? 0,
              'status': (v['is_active'] ?? true) ? 'Active' : 'Inactive',
            });
          }
          if (tempVendors.isNotEmpty) tempVendorsCount = tempVendors.length;
        } catch (_) {}
      }

      // 3. Candidates
      if (results[2].statusCode == 200) {
        try {
          final body = jsonDecode(results[2].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          for (var c in items) {
            final rawId = c['id']?.toString() ?? '';
            final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : (rawId.isNotEmpty ? rawId : 'CND-001');
            tempCandidates.add({
              'id': shortId,
              'name': c['full_name']?.toString() ?? 'Candidate Name',
              'email': c['email']?.toString() ?? 'candidate@example.com',
              'phone': c['phone']?.toString() ?? 'N/A',
              'vendor': c['vendor_name']?.toString() ?? c['company_name']?.toString() ?? 'Vendor',
              'videos': num.tryParse(c['videos_count']?.toString() ?? '1')?.toInt() ?? 1,
              'status': (c['is_active'] ?? true) ? 'Active' : 'Inactive',
            });
          }
          if (tempCandidates.isNotEmpty) tempCandidatesCount = tempCandidates.length;
        } catch (_) {}
      }

      // 4. Videos
      if (results[3].statusCode == 200) {
        try {
          final body = jsonDecode(results[3].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          for (var vid in items) {
            final id = vid['id']?.toString() ?? '';
            final st = (vid['status'] ?? 'pending').toString().toLowerCase();
            final shortId = id.length >= 8 ? id.substring(0, 8) : (id.isNotEmpty ? id : 'VID-001');

            if (!st.contains('admin_approved') && !st.contains('admin_rejected')) {
              tempQC.add({
                'id': shortId,
                'raw_id': id,
                'title': vid['title']?.toString() ?? 'Video Recording',
                'candidateName': vid['candidate_name']?.toString() ?? vid['candidateName']?.toString() ?? 'Candidate',
                'vendor': vid['vendor_name']?.toString() ?? vid['vendor']?.toString() ?? 'Acme Video Solutions',
                'duration': '${vid['duration'] ?? 15} Mins',
                'time': 'Just Now',
                'env': vid['environment_tag']?.toString() ?? 'Indoor',
                'score': 95,
                'status': 'Pending QC',
                'assignedTo': vid['assigned_to']?.toString() ?? 'Unassigned',
              });
            }
          }
        } catch (_) {}
      }

      // 5. Notifications
      if (results[4].statusCode == 200) {
        try {
          final body = jsonDecode(results[4].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          for (var n in items) {
            tempNotifs.add({
              'title': n['title']?.toString() ?? 'Activity Update',
              'desc': n['message']?.toString() ?? '',
              'time': 'Just Now',
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _totalVendorsCount = tempVendorsCount;
          _totalCandidatesCount = tempCandidatesCount;
          _totalVideosCount = tempVideosCount > 0 ? tempVideosCount : (tempApproved + tempRejected + tempPendingQC);
          _pendingQCCount = tempPendingQC > 0 ? tempPendingQC : tempQC.length;
          _approvedCount = tempApproved;
          _rejectedCount = tempRejected;

          _dailyTrends.clear();
          _dailyTrends.addAll(tempTrends);

          _vendors.clear();
          _vendors.addAll(tempVendors);

          _candidates.clear();
          _candidates.addAll(tempCandidates);

          _qcSubmissions.clear();
          _qcSubmissions.addAll(tempQC);

          _activities.clear();
          _activities.addAll(tempNotifs);
        });
      }
    } catch (e) {
      debugPrint('Dashboard data load exception: $e');
    } finally {
      _isFetching = false;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _triggerDownload(String url) {
    if (kIsWeb) {
      try {
        web.windowOpen(url, '_blank');
      } catch (_) {}
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading report: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _activeNavIndex.clamp(0, 3),
        children: [
          _buildMainDashboardTab(),
          _buildVendorsTab(),
          _buildCandidatesTab(),
          _buildQCTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PoweredByFooter(),
            BottomNavigationBar(
              currentIndex: _activeNavIndex.clamp(0, 3),
              onTap: (idx) => setState(() => _activeNavIndex = idx),
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF2563EB),
              unselectedItemColor: const Color(0xFF94A3B8),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Vendors'),
                BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Candidates'),
                BottomNavigationBarItem(icon: Icon(Icons.verified_user_rounded), label: 'QC Queue'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 1. MAIN DASHBOARD TAB
  Widget _buildMainDashboardTab() {
    final calcTotal = _totalVideosCount > 0 ? _totalVideosCount : (_approvedCount + _rejectedCount + _pendingQCCount);
    final approvedPct = calcTotal > 0 ? ((_approvedCount / calcTotal) * 100).toStringAsFixed(1) : '0.0';

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Curved Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 48, left: 20, right: 20, bottom: 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Platform Management & Control', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5)),
                        onPressed: _handleLogout,
                        tooltip: 'Logout',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Hello, Admin 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text("Here's what's happening today", style: TextStyle(fontSize: 13, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Cards Horizontal Scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatCard('Total Vendors', '${_totalVendorsCount > 0 ? _totalVendorsCount : _vendors.length}', 'Active', const Color(0xFF16A34A), Icons.storefront_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                  const SizedBox(width: 12),
                  _buildStatCard('Total Candidates', '${_totalCandidatesCount > 0 ? _totalCandidatesCount : _candidates.length}', 'Registered', const Color(0xFF9333EA), Icons.people_rounded, const Color(0xFF9333EA), const Color(0xFFF3E8FF)),
                  const SizedBox(width: 12),
                  _buildStatCard('Total Videos', '$calcTotal', 'Uploaded', const Color(0xFF0284C7), Icons.videocam_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE)),
                  const SizedBox(width: 12),
                  _buildStatCard('Pending QC', '$_pendingQCCount', 'Review', const Color(0xFFD97706), Icons.assignment_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Uploads Overview Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Uploads Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Success: $approvedPct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TrendChartPainter(_dailyTrends),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Actions Horizontal Row
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildQuickActionBtn(Icons.storefront_rounded, 'Vendor\nManagement', const Color(0xFF0284C7), () => setState(() => _activeNavIndex = 1)),
                  const SizedBox(width: 12),
                  _buildQuickActionBtn(Icons.people_rounded, 'Candidate\nRoster', const Color(0xFF9333EA), () => setState(() => _activeNavIndex = 2)),
                  const SizedBox(width: 12),
                  _buildQuickActionBtn(Icons.verified_user_rounded, 'QC Review\nPanel', const Color(0xFF16A34A), () => setState(() => _activeNavIndex = 3)),
                  const SizedBox(width: 12),
                  _buildQuickActionBtn(Icons.description_rounded, 'Reports &\nExport', const Color(0xFF2563EB), () => _triggerDownload('$_apiBaseUrl/qc-reviews/export/csv')),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 2. VENDORS TAB
  Widget _buildVendorsTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vendor Directory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Registered Partner Companies', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddVendorDialog,
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Add Vendor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_vendors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No Vendors Registered Yet', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _vendors.length,
                  itemBuilder: (ctx, i) {
                    final v = _vendors[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['name'] ?? 'Vendor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Code: ${v['vendor_code']} | Contact: ${v['contact']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                Text(v['email'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                            child: Text(v['status'] ?? 'Active', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 3. CANDIDATES TAB
  Widget _buildCandidatesTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Candidate Directory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const Text('Registered Subjects & Record Profiles', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              if (_candidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No Candidates Registered Yet', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _candidates.length,
                  itemBuilder: (ctx, i) {
                    final c = _candidates[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Color(0xFFEFF6FF), child: Icon(Icons.person, color: Color(0xFF2563EB))),
                        title: Text(c['name'] ?? 'Candidate', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Vendor: ${c['vendor']} | Email: ${c['email']}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                          child: Text(c['status'] ?? 'Active', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. QC QUEUE TAB
  Widget _buildQCTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QC Review Queue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Candidate Uploaded Video Queue', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _triggerDownload('$_apiBaseUrl/qc-reviews/export/csv'),
                    icon: const Icon(Icons.download, size: 16, color: Colors.white),
                    label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_qcSubmissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No Pending Videos in QC Queue', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _qcSubmissions.length,
                  itemBuilder: (ctx, i) {
                    final item = _qcSubmissions[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['title'] ?? 'Video Recording', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Candidate: ${item['candidateName']} • Vendor: ${item['vendor']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                                child: Text(item['status'] ?? 'Pending QC', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                              Text('Duration: ${item['duration']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, String subtext, Color subColor, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtext, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor)),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  void _showAddVendorDialog() {
    _vendorNameCtrl.clear();
    _contactPersonCtrl.clear();
    _vendorEmailCtrl.clear();
    _vendorPhoneCtrl.clear();
    _vendorPasswordCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _vendorNameCtrl, decoration: const InputDecoration(labelText: 'Company Name')),
                TextField(controller: _contactPersonCtrl, decoration: const InputDecoration(labelText: 'Contact Person')),
                TextField(controller: _vendorEmailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
                TextField(controller: _vendorPhoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                TextField(
                  controller: _vendorPasswordCtrl,
                  obscureText: _obscureVendorPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureVendorPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => _obscureVendorPassword = !_obscureVendorPassword),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final company = _vendorNameCtrl.text.trim();
                final email = _vendorEmailCtrl.text.trim();
                if (company.isEmpty || email.isEmpty) return;

                try {
                  final headers = await AuthService.getAuthHeaders();
                  await http.post(
                    Uri.parse('$_apiBaseUrl/vendors'),
                    headers: headers,
                    body: jsonEncode({
                      'company_name': company,
                      'contact_person': _contactPersonCtrl.text.trim(),
                      'email': email,
                      'phone': _vendorPhoneCtrl.text.trim(),
                      'password': _vendorPasswordCtrl.text.trim().isNotEmpty ? _vendorPasswordCtrl.text.trim() : 'vendor123',
                    }),
                  );
                } catch (_) {}

                if (mounted) {
                  Navigator.pop(ctx);
                  _loadDashboardData();
                }
              },
              child: const Text('Create Vendor'),
            ),
          ],
        ),
      ),
    );
  }
}

// 7-Day Trend Chart Painter
class _TrendChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> trends;
  _TrendChartPainter(this.trends);

  @override
  void paint(Canvas canvas, Size size) {
    if (trends.isEmpty) {
      final textPainter = TextPainter(
        text: const TextSpan(text: '7-Day Trend Data Ready', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return;
    }

    final values = trends.map((t) => (t['uploaded'] as int? ?? 0).toDouble()).toList();
    final n = values.length;
    final maxVal = values.fold<double>(1.0, (a, b) => b > a ? b : a);

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = n <= 1 ? size.width / 2 : (i / (n - 1)) * size.width;
      final y = size.height - 20.0 - ((values[i] / maxVal) * (size.height - 30.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter old) => old.trends != trends;
}
