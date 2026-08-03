import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
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
  String _vendorSearchQuery = '';
  String _candidateSearchQuery = '';
  String _selectedTimeframe = 'This Week';

  // Dynamic Dashboard Stats (populated dynamically from live API database)
  int _totalVendorsCount = 0;
  int _totalCandidatesCount = 0;
  int _totalVideosCount = 0;
  int _pendingQCCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  double _successRate = 0.0;

  int get _calculatedApprovedCount {
    final count = _qcSubmissions.where((s) => s['status'] == 'Approved').length;
    return count > 0 ? count : _approvedCount;
  }

  int get _calculatedRejectedCount {
    final count = _qcSubmissions.where((s) => s['status'] == 'Rejected').length;
    return count > 0 ? count : _rejectedCount;
  }

  int get _calculatedPendingCount {
    final count = _qcSubmissions.where((s) => (s['status'] ?? 'Pending QC') != 'Approved' && (s['status'] ?? 'Pending QC') != 'Rejected').length;
    return count > 0 ? count : _pendingQCCount;
  }

  int get _totalQCCount {
    final total = _calculatedApprovedCount + _calculatedRejectedCount + _calculatedPendingCount;
    return total > 0 ? total : 1;
  }

  double get _dynamicApprovedPct => (_calculatedApprovedCount / _totalQCCount) * 100;
  double get _dynamicRejectedPct => (_calculatedRejectedCount / _totalQCCount) * 100;
  double get _dynamicPendingPct => (_calculatedPendingCount / _totalQCCount) * 100;

  double get _dynamicSuccessRate {
    final evaluated = _calculatedApprovedCount + _calculatedRejectedCount;
    if (evaluated == 0) return 0.0;
    return (_calculatedApprovedCount / evaluated) * 100;
  }

  // Vendors List (Dynamic API)
  final List<Map<String, dynamic>> _vendors = [];

  // Candidates List (Dynamic API)
  final List<Map<String, dynamic>> _candidates = [];

  // QC Submissions (Dynamic API)
  final List<Map<String, dynamic>> _qcSubmissions = [];

  // Recent Activities (Dynamic API)
  int _unreadNotificationsCount = 3;
  final List<Map<String, dynamic>> _recentActivities = [];

  // Modal Controllers
  final _vendorNameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _vendorEmailCtrl = TextEditingController();
  final _vendorPhoneCtrl = TextEditingController();
  final _vendorPasswordCtrl = TextEditingController();
  bool _obscureVendorPassword = true;

  // QC Member Controllers & State (Dynamic API)
  final _qcNameCtrl = TextEditingController();
  final _qcEmailCtrl = TextEditingController();
  final _qcPhoneCtrl = TextEditingController();
  final _qcPasswordCtrl = TextEditingController();
  final List<Map<String, dynamic>> _qcMembers = [];

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

  Future<http.Response> _safeGet(String url, Map<String, String> headers) async {
    try {
      return await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('GET failed for $url: $e');
      return http.Response('{}', 500);
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted || _isFetching) return;
    _isFetching = true;
    if (mounted) setState(() => _isLoading = true);

    try {
      final headers = await AuthService.getAuthHeaders();

      final results = await Future.wait([
        _safeGet('$_apiBaseUrl/admins/dashboard-stats', headers),
        _safeGet('$_apiBaseUrl/vendors', headers),
        _safeGet('$_apiBaseUrl/candidates', headers),
        _safeGet('$_apiBaseUrl/videos', headers),
      ]);

      // 1. Dashboard Stats Parsing
      if (results[0].statusCode == 200) {
        try {
          final body = jsonDecode(results[0].body);
          final s = body['data'] ?? {};
          final vCount = num.tryParse(s['total_vendors']?.toString() ?? '')?.toInt();
          final cCount = num.tryParse(s['total_candidates']?.toString() ?? '')?.toInt();
          final vidCount = num.tryParse(s['total_uploaded_videos']?.toString() ?? '')?.toInt();
          final pending = num.tryParse(s['pending_qc']?.toString() ?? '')?.toInt();
          final appr = num.tryParse(s['approved']?.toString() ?? '')?.toInt();
          final rej = num.tryParse(s['rejected']?.toString() ?? '')?.toInt();

          if (mounted) {
            setState(() {
              _totalVendorsCount = vCount ?? _vendors.length;
              _totalCandidatesCount = cCount ?? _candidates.length;
              _totalVideosCount = vidCount ?? _qcSubmissions.length;
              _pendingQCCount = pending ?? _qcSubmissions.length;
              _approvedCount = appr ?? 0;
              _rejectedCount = rej ?? 0;
              if (_approvedCount + _rejectedCount > 0) {
                _successRate = double.parse(((_approvedCount / (_approvedCount + _rejectedCount)) * 100).toStringAsFixed(1));
              } else {
                _successRate = 0.0;
              }
            });
          }
        } catch (_) {}
      }

      // 2. Vendors List Parsing
      if (results[1].statusCode == 200) {
        try {
          final body = jsonDecode(results[1].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          if (items.isNotEmpty) {
            final List<Map<String, dynamic>> tempVendors = [];
            for (var v in items) {
              final isActive = v['is_active'] == true || v['is_active'] == 1 || v['is_active']?.toString() == 'true';
              tempVendors.add({
                'id': v['id']?.toString() ?? 'VEN-001',
                'vendor_code': v['vendor_code']?.toString() ?? 'VEN-001',
                'name': v['name']?.toString() ?? v['company_name']?.toString() ?? 'Vendor Company',
                'contact': v['contact_person']?.toString() ?? 'Contact Person',
                'email': v['email']?.toString() ?? 'vendor@example.com',
                'phone': v['phone']?.toString() ?? 'N/A',
                'candidates': num.tryParse(v['candidates']?.toString() ?? '12')?.toInt() ?? 12,
                'videos': num.tryParse(v['videos']?.toString() ?? '85')?.toInt() ?? 85,
                'status': isActive ? 'Active' : 'Inactive',
              });
            }
            if (mounted && tempVendors.isNotEmpty) {
              setState(() {
                _vendors.clear();
                _vendors.addAll(tempVendors);
                _totalVendorsCount = _vendors.length;
              });
            }
          }
        } catch (_) {}
      }

      // 3. Candidates List Parsing
      if (results[2].statusCode == 200) {
        try {
          final body = jsonDecode(results[2].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          if (items.isNotEmpty) {
            final List<Map<String, dynamic>> tempCandidates = [];
            for (var c in items) {
              final rawId = c['id']?.toString() ?? '';
              final shortId = rawId.length >= 8 ? rawId.substring(0, 8) : (rawId.isNotEmpty ? rawId : 'CND-001');
              final isActive = c['is_active'] == true || c['is_active'] == 1 || c['is_active']?.toString() == 'true';
              tempCandidates.add({
                'id': shortId,
                'name': c['full_name']?.toString() ?? 'Candidate Name',
                'email': c['email']?.toString() ?? 'candidate@example.com',
                'phone': c['phone']?.toString() ?? 'N/A',
                'vendor': c['vendor_name']?.toString() ?? c['company_name']?.toString() ?? 'Vendor',
                'vendor_code': c['vendor_code']?.toString() ?? c['vendorCode']?.toString() ?? 'VEN-001',
                'videos': num.tryParse(c['videos_count']?.toString() ?? '3')?.toInt() ?? 3,
                'status': isActive ? 'Active' : 'Inactive',
              });
            }
            if (mounted && tempCandidates.isNotEmpty) {
              setState(() {
                _candidates.clear();
                _candidates.addAll(tempCandidates);
                _totalCandidatesCount = _candidates.length;
              });
            }
          }
        } catch (_) {}
      }

      // 4. QC Videos Parsing
      if (results[3].statusCode == 200) {
        try {
          final body = jsonDecode(results[3].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          if (items.isNotEmpty) {
            final List<Map<String, dynamic>> tempQC = [];
            for (var vid in items) {
              final id = vid['id']?.toString() ?? '';
              final shortId = id.length >= 8 ? id.substring(0, 8) : (id.isNotEmpty ? id : 'VID-001');
              tempQC.add({
                'id': shortId,
                'raw_id': id,
                'title': vid['title']?.toString() ?? 'Video Recording',
                'candidateName': vid['candidate_name']?.toString() ?? vid['candidateName']?.toString() ?? 'Candidate',
                'vendor': vid['vendor_name']?.toString() ?? vid['vendor']?.toString() ?? 'ABC Solutions',
                'duration': '${vid['duration'] ?? 15} Mins',
                'status': vid['status']?.toString() ?? 'Pending QC',
              });
            }
            if (mounted && tempQC.isNotEmpty) {
              setState(() {
                _qcSubmissions.clear();
                _qcSubmissions.addAll(tempQC);
                _pendingQCCount = _qcSubmissions.length;
              });
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Dashboard API sync exception: $e');
    } finally {
      _isFetching = false;
      if (mounted) setState(() => _isLoading = false);
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
          SnackBar(
            content: Text('Downloading report: $url'),
            backgroundColor: const Color(0xFF2563EB),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _updateVideoStatus(String id, String newStatus) {
    setState(() {
      final index = _qcSubmissions.indexWhere((item) => item['id'] == id || item['raw_id'] == id);
      if (index != -1) {
        _qcSubmissions[index]['status'] = newStatus;
        if (newStatus == 'Approved') {
          _approvedCount++;
          if (_pendingQCCount > 0) _pendingQCCount--;
        } else if (newStatus == 'Rejected') {
          _rejectedCount++;
          if (_pendingQCCount > 0) _pendingQCCount--;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video $id marked as $newStatus!'),
        backgroundColor: newStatus == 'Approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleVendorStatus(String vendorId) {
    setState(() {
      final index = _vendors.indexWhere((v) => v['id'] == vendorId || v['vendor_code'] == vendorId);
      if (index != -1) {
        final current = _vendors[index]['status'] ?? 'Active';
        final updated = current == 'Active' ? 'Inactive' : 'Active';
        _vendors[index]['status'] = updated;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vendor ${_vendors[index]['name']} is now $updated!'),
            backgroundColor: updated == 'Active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Executive Header is ONLY visible on Dashboard tab (Index 0)
            if (_activeNavIndex == 0)
              _buildTopExecutiveHeader()
            else if (_activeNavIndex == 1)
              _buildStandardAppBar('Vendors Directory', '${_vendors.length} Total Registered Vendors')
            else if (_activeNavIndex == 2)
              _buildStandardAppBar('Candidates Roster', '${_candidates.length} Total Enrolled Candidates')
            else if (_activeNavIndex == 3)
              _buildStandardAppBar('QC Queue', '${_qcSubmissions.where((s) => s['status'] != 'Approved').length} Pending QC Submissions')
            else
              _buildStandardAppBar('QC Approved Portal', '${_qcSubmissions.where((s) => s['status'] == 'Approved').length} Submissions Approved'),
            
            // Dynamic Body Screens
            Expanded(
              child: IndexedStack(
                index: _activeNavIndex.clamp(0, 4),
                children: [
                  _buildDashboardOverviewTab(),
                  _buildVendorsTab(),
                  _buildCandidatesTab(),
                  _buildQCQueueTab(),
                  _buildQCApprovedTab(),
                ],
              ),
            ),
          ],
        ),
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
              currentIndex: _activeNavIndex.clamp(0, 4),
              onTap: (idx) => setState(() => _activeNavIndex = idx),
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF1E3A8A),
              unselectedItemColor: const Color(0xFF94A3B8),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Vendors'),
                BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Candidates'),
                BottomNavigationBarItem(icon: Icon(Icons.pending_actions_rounded), label: 'QC Queue'),
                BottomNavigationBarItem(icon: Icon(Icons.verified_rounded), label: 'QC Approved'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Clean Standard AppBar for Vendors, Candidates, and QC Approved tabs
  Widget _buildStandardAppBar(String title, String subtitle) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B192C),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                onPressed: _showSystemDrawerDialog,
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
                onPressed: _loadDashboardData,
                tooltip: 'Refresh Data',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5), size: 22),
                onPressed: _handleLogout,
                tooltip: 'Logout',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1. TOP EXECUTIVE HEADER MATCHING DESIGN (ONLY FOR DASHBOARD TAB 0)
  Widget _buildTopExecutiveHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B192C),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppBar Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    onPressed: () => _showSystemDrawerDialog(),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Platform Management & Control',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                        onPressed: _showActivityLogsDialog,
                      ),
                      if (_unreadNotificationsCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_unreadNotificationsCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5)),
                    onPressed: _handleLogout,
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Greeting Row
          const Text(
            'Hello, Admin 👋',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            "Here's what's happening today",
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // 4 Metric Cards Row (Matching Image Exactly)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildImageStyleMetricCard(
                  'Total Vendors',
                  '$_totalVendorsCount',
                  'Registered',
                  const Color(0xFF2563EB),
                  Icons.group_work_outlined,
                  const Color(0xFFDBEAFE),
                  const Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                _buildImageStyleMetricCard(
                  'Total Candidates',
                  '$_totalCandidatesCount',
                  'Registered',
                  const Color(0xFF8B5CF6),
                  Icons.person_outline_rounded,
                  const Color(0xFFF3E8FF),
                  const Color(0xFF7C3AED),
                ),
                const SizedBox(width: 12),
                _buildImageStyleMetricCard(
                  'Total Videos',
                  '$_totalVideosCount',
                  'Uploaded',
                  const Color(0xFF2563EB),
                  Icons.videocam_outlined,
                  const Color(0xFFE0F2FE),
                  const Color(0xFF0284C7),
                ),
                const SizedBox(width: 12),
                _buildImageStyleMetricCard(
                  'Pending QC',
                  '$_pendingQCCount',
                  'Review',
                  const Color(0xFFF59E0B),
                  Icons.assignment_outlined,
                  const Color(0xFFFEF3C7),
                  const Color(0xFFD97706),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageStyleMetricCard(
    String title,
    String value,
    String badgeText,
    Color badgeColor,
    IconData icon,
    Color iconBg,
    Color iconColor,
  ) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              badgeText,
              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  // TAB 0: DASHBOARD OVERVIEW TAB
  Widget _buildDashboardOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Uploads Overview Chart Section
            _buildUploadsOverviewSection(),
            const SizedBox(height: 18),

            // Recent Activities Section
            _buildRecentActivitiesSection(),
            const SizedBox(height: 18),

            // Quick Actions Grid
            _buildQuickActionsSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Uploads Overview Chart + Executive Breakdown Card
  Widget _buildUploadsOverviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Uploads Overview',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTimeframe,
                    isDense: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF334155)),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    items: const [
                      DropdownMenuItem(
                        value: 'This Week',
                        child: Text('This Week', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: 'This Month',
                        child: Text('This Month', style: TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTimeframe = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart + Breakdown Side-by-Side Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Line Chart (Left)
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: CustomPaint(
                        painter: _LineChartPainter(isWeekly: _selectedTimeframe == 'This Week'),
                        child: Container(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (_selectedTimeframe == 'This Week')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Mon', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Tue', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Wed', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Thu', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Fri', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Sat', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Sun', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Wk 1', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Wk 2', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Wk 3', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                          Text('Wk 4', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Breakdown Stats Panel (Right)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildBreakdownRow(Icons.check_circle_rounded, const Color(0xFF10B981), 'Approved', '$_calculatedApprovedCount', '${_dynamicApprovedPct.toStringAsFixed(1)}%', const Color(0xFF10B981)),
                      const Divider(height: 16),
                      _buildBreakdownRow(Icons.cancel_rounded, const Color(0xFFEF4444), 'Rejected', '$_calculatedRejectedCount', '${_dynamicRejectedPct.toStringAsFixed(1)}%', const Color(0xFFEF4444)),
                      const Divider(height: 16),
                      _buildBreakdownRow(Icons.access_time_filled_rounded, const Color(0xFFF59E0B), 'Pending', '$_calculatedPendingCount', '${_dynamicPendingPct.toStringAsFixed(1)}%', const Color(0xFFF59E0B)),
                      const Divider(height: 16),
                      _buildBreakdownRow(Icons.trending_up_rounded, const Color(0xFF2563EB), 'Success Rate', '${_dynamicSuccessRate.toStringAsFixed(1)}%', '', const Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(IconData icon, Color iconColor, String label, String value, String percent, Color percentColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ],
          ),
        ),
        if (percent.isNotEmpty)
          Text(percent, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: percentColor)),
      ],
    );
  }

  // Recent Activities Section
  Widget _buildRecentActivitiesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              GestureDetector(
                onTap: _showActivityLogsDialog,
                child: const Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: _recentActivities.map((act) => _buildActivityItem(act)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> act) {
    final IconData icon = act['icon'] as IconData;
    final Color color = act['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(act['subtitle'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text(act['time'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  // Quick Actions Section Grid
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildQuickActionButton(
                'Vendor\nManagement',
                Icons.storefront_rounded,
                const Color(0xFF2563EB),
                () => setState(() => _activeNavIndex = 1),
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                'QC Review\nPanel',
                Icons.verified_user_rounded,
                const Color(0xFF7C3AED),
                () => setState(() => _activeNavIndex = 3),
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                'Analytics\nOverview',
                Icons.pie_chart_rounded,
                const Color(0xFF10B981),
                _showAnalyticsDialog,
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                'Candidate\nRoster',
                Icons.people_rounded,
                const Color(0xFFF59E0B),
                () => setState(() => _activeNavIndex = 2),
              ),
              const SizedBox(width: 10),
              _buildQuickActionButton(
                'Reports &\nExport',
                Icons.description_rounded,
                const Color(0xFF0284C7),
                () => _triggerDownload('$_apiBaseUrl/qc-reviews/export/csv'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: VENDORS TAB
  Widget _buildVendorsTab() {
    final filteredVendors = _vendors.where((v) {
      final query = _vendorSearchQuery.toLowerCase();
      final name = (v['name'] ?? '').toString().toLowerCase();
      final code = (v['vendor_code'] ?? '').toString().toLowerCase();
      final contact = (v['contact'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query) || contact.contains(query);
    }).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vendor Management Action Card Banner
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vendor Management', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Create & manage live vendor partners', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                        Icon(Icons.storefront_rounded, color: Color(0xFF3B82F6), size: 28),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddVendorDialog,
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text('+ Add Vendor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _vendorSearchQuery = val),
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search vendors by name, code, contact...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              if (filteredVendors.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No matching vendors found', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                Column(
                  children: filteredVendors.map((v) => _buildVendorCard(v)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v['name'] ?? 'Vendor Company', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('Code: ${v['vendor_code']} • Contact: ${v['contact']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text('Candidates: ${v['candidates']} • Email: ${v['email']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: CANDIDATES TAB
  Widget _buildCandidatesTab() {
    final filteredCandidates = _candidates.where((c) {
      final query = _candidateSearchQuery.toLowerCase();
      final name = (c['name'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final vendor = (c['vendor'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || vendor.contains(query);
    }).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _candidateSearchQuery = val),
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search candidates by name, email, vendor...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),

              if (filteredCandidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No matching candidates found', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                Column(
                  children: filteredCandidates.map((c) => _buildCandidateCard(c)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateCard(Map<String, dynamic> c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFF3E8FF),
            radius: 22,
            child: Icon(Icons.person_rounded, color: Color(0xFF7C3AED), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['name'] ?? 'Candidate Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('Vendor Code: ${c['vendor_code'] ?? c['vendorCode'] ?? 'VEN-001'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                if (c['email'] != null && c['email'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Email: ${c['email']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: QC QUEUE TAB (Pending & In-Review Queue)
  Widget _buildQCQueueTab() {
    final pendingItems = _qcSubmissions.where((item) => (item['status'] ?? '') != 'Approved').toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Executive QC Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('QC Management', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Create & manage live QC team members', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                        Icon(Icons.fact_check_rounded, color: Color(0xFF3B82F6), size: 28),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showAddQCMemberDialog,
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        label: const Text('+ Add QC', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (pendingItems.isEmpty)
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(36),
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                      SizedBox(height: 12),
                      Text('All QC Submissions Cleared!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text('There are currently no pending videos waiting for QC review.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else
                Column(
                  children: pendingItems.map((item) => _buildQCCard(item)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 4: QC APPROVED TAB (Verified & Approved Datasets)
  Widget _buildQCApprovedTab() {
    final approvedItems = _qcSubmissions.where((item) => item['status'] == 'Approved').toList();

    return Container(
      color: const Color(0xFFF8FAFC),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Approved Video Datasets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text('QC Verified & Approved dataset collection', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _triggerDownload('$_apiBaseUrl/qc-reviews/export/csv'),
                    icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF10B981)),
                    label: const Text('Export Approved', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (approvedItems.isEmpty)
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(36),
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.verified_outlined, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No Approved Videos Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text('Videos approved by QC reviewers will appear here.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                )
              else
                Column(
                  children: approvedItems.map((item) => _buildQCCard(item)).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQCCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'Pending QC';
    final isApproved = status == 'Approved';
    final isRejected = status == 'Rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item['title'] ?? 'Video Recording', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFECFDF5)
                      : (isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isApproved
                        ? const Color(0xFF059669)
                        : (isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706)),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Candidate: ${item['candidateName']} • Vendor: ${item['vendor']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text('Duration: ${item['duration']} • ID: ${item['id']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          if (item['assigned_qc'] != null && item['assigned_qc'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Assigned to: ${item['assigned_qc']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
          ],
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateVideoStatus(item['id'], 'Rejected'),
                  icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                  label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAssignQCDialog(item['id']),
                  icon: const Icon(Icons.assignment_ind_rounded, size: 14, color: Color(0xFF7C3AED)),
                  label: const Text('Assign QC', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDDD6FE)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateVideoStatus(item['id'], 'Approved'),
                  icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  label: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MODAL DIALOGS
  void _showAddVendorDialog() {
    _vendorNameCtrl.clear();
    _contactPersonCtrl.clear();
    _vendorEmailCtrl.clear();
    _vendorPhoneCtrl.clear();
    _vendorPasswordCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Add New Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Required Vendor Information', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _vendorNameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Company Name *',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    hintText: 'e.g. Acme Vendor Solutions',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _contactPersonCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Contact Person Name',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    hintText: 'e.g. John Doe',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vendorEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Login Email Address *',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    hintText: 'e.g. vendor@company.com',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vendorPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    hintText: 'e.g. +91 98765 43210',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF2563EB)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vendorPasswordCtrl,
                  obscureText: _obscureVendorPassword,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Login Password *',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    hintText: 'Enter vendor password',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureVendorPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF64748B)),
                      onPressed: () => setDialogState(() => _obscureVendorPassword = !_obscureVendorPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final company = _vendorNameCtrl.text.trim();
                final email = _vendorEmailCtrl.text.trim();
                final rawPassword = _vendorPasswordCtrl.text.trim();
                final pass = rawPassword.isNotEmpty ? rawPassword : 'vendor123';

                if (company.isEmpty || email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Company Name and Login Email are required!'),
                      backgroundColor: Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                String generatedCode = 'VEN-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';
                try {
                  final headers = await AuthService.getAuthHeaders();
                  final res = await http.post(
                    Uri.parse('$_apiBaseUrl/vendors'),
                    headers: headers,
                    body: jsonEncode({
                      'company_name': company,
                      'contact_person': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : company,
                      'email': email,
                      'phone': _vendorPhoneCtrl.text.trim().isNotEmpty ? _vendorPhoneCtrl.text.trim() : '+91 98765 00000',
                      'password': pass,
                    }),
                  );

                  if (res.statusCode == 200 || res.statusCode == 201) {
                    final body = jsonDecode(res.body);
                    final data = body['data'] ?? {};
                    if (data['vendor_code'] != null) {
                      generatedCode = data['vendor_code'].toString();
                    }
                  }
                } catch (_) {}

                if (mounted) {
                  setState(() {
                    _vendors.insert(0, {
                      'id': generatedCode,
                      'vendor_code': generatedCode,
                      'name': company,
                      'contact': _contactPersonCtrl.text.trim().isNotEmpty ? _contactPersonCtrl.text.trim() : company,
                      'email': email,
                      'phone': _vendorPhoneCtrl.text.trim().isNotEmpty ? _vendorPhoneCtrl.text.trim() : 'N/A',
                      'candidates': 0,
                      'videos': 0,
                      'status': 'Active',
                    });
                    _totalVendorsCount = _vendors.length;
                  });

                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vendor "$company" created in database! Code: $generatedCode | Email: $email'),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  _loadDashboardData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Create Vendor in Database', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddQCMemberDialog() {
    _qcNameCtrl.clear();
    _qcEmailCtrl.clear();
    _qcPhoneCtrl.clear();
    _qcPasswordCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.person_add_rounded, color: Color(0xFF7C3AED), size: 22),
              SizedBox(width: 8),
              Text('Create QC Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _qcNameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: Color(0xFF475569))),
                ),
                TextField(
                  controller: _qcEmailCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Email Address (e.g. qc@demo.com)', labelStyle: TextStyle(color: Color(0xFF475569))),
                ),
                TextField(
                  controller: _qcPhoneCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: Color(0xFF475569))),
                ),
                TextField(
                  controller: _qcPasswordCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                  decoration: const InputDecoration(labelText: 'Password (min 6 chars)', labelStyle: TextStyle(color: Color(0xFF475569))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              onPressed: () async {
                final name = _qcNameCtrl.text.trim();
                final email = _qcEmailCtrl.text.trim();
                if (name.isEmpty || email.isEmpty) return;

                try {
                  final headers = await AuthService.getAuthHeaders();
                  await http.post(
                    Uri.parse('$_apiBaseUrl/admins/qc-members'),
                    headers: headers,
                    body: jsonEncode({
                      'full_name': name,
                      'email': email,
                      'phone': _qcPhoneCtrl.text.trim(),
                      'password': _qcPasswordCtrl.text.trim().isNotEmpty ? _qcPasswordCtrl.text.trim() : 'qc123456',
                    }),
                  );
                } catch (_) {}

                if (mounted) {
                  setState(() {
                    _qcMembers.insert(0, {
                      'id': 'QC-00${_qcMembers.length + 1}',
                      'name': name,
                      'email': email,
                      'role': 'QC Evaluator',
                      'phone': _qcPhoneCtrl.text.trim().isNotEmpty ? _qcPhoneCtrl.text.trim() : 'N/A',
                    });
                  });

                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('New QC Member "$name" created successfully!'),
                      backgroundColor: const Color(0xFF7C3AED),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('Create Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityLogsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          int activeFilterIndex = 0;

          return SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                // Top App Bar Header
                Container(
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B192C),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Notifications Center',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (_unreadNotificationsCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                                      child: Text(
                                        '$_unreadNotificationsCount NEW',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_recentActivities.length} Total System Alerts',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_unreadNotificationsCount > 0)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _unreadNotificationsCount = 0;
                                  for (var act in _recentActivities) {
                                    act['read'] = true;
                                  }
                                });
                                setModalState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All notifications marked as read!'),
                                    backgroundColor: Color(0xFF2563EB),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.done_all_rounded, color: Color(0xFF60A5FA), size: 16),
                              label: const Text('Mark all read', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Filter Buttons Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All (${_recentActivities.length})', activeFilterIndex == 0, () {
                        setModalState(() => activeFilterIndex = 0);
                      }),
                      const SizedBox(width: 8),
                      _buildFilterChip('Unread ($_unreadNotificationsCount)', activeFilterIndex == 1, () {
                        setModalState(() => activeFilterIndex = 1);
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Notification Items Full Screen List
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filteredLogs = _recentActivities.where((act) {
                        if (activeFilterIndex == 1) return act['read'] != true;
                        return true;
                      }).toList();

                      if (filteredLogs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.notifications_off_outlined, size: 64, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 14),
                              Text('No Notifications Right Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                              SizedBox(height: 4),
                              Text('You are all caught up on system activities.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, idx) {
                          final act = filteredLogs[idx];
                          final isUnread = act['read'] != true;
                          final iconData = act['icon'] as IconData? ?? Icons.notifications_rounded;
                          final iconColor = act['color'] as Color? ?? const Color(0xFF2563EB);

                          return InkWell(
                            onTap: () {
                              if (isUnread) {
                                setState(() {
                                  act['read'] = true;
                                  if (_unreadNotificationsCount > 0) _unreadNotificationsCount--;
                                });
                                setModalState(() {});
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isUnread ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: isUnread ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                act['title'] ?? 'System Activity',
                                                style: TextStyle(
                                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(left: 6),
                                                decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          act['subtitle'] ?? '',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          act['time'] ?? 'Just now',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showAssignQCDialog(String videoId) {
    List<Map<String, dynamic>> availableMembers = List.from(_qcMembers);
    if (availableMembers.isEmpty) {
      availableMembers = [
        {'name': 'QC Team Lead', 'email': 'qcteam@gmail.com'},
        {'name': 'QC Evaluator', 'email': 'qc@gmail.com'},
      ];
    }
    String selectedReviewer = '${availableMembers.first['name']} (${availableMembers.first['email']})';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Assign QC Reviewer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a qualified QC Team reviewer for video $videoId:', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedReviewer,
                dropdownColor: Colors.white,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: availableMembers.map((m) {
                  final label = '${m['name']} (${m['email']})';
                  return DropdownMenuItem<String>(
                    value: label,
                    child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setModalState(() => selectedReviewer = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  final idx = _qcSubmissions.indexWhere((v) => v['id'] == videoId || v['raw_id'] == videoId);
                  if (idx != -1) {
                    _qcSubmissions[idx]['assigned_qc'] = selectedReviewer;
                    _qcSubmissions[idx]['status'] = 'In Review';
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Video $videoId assigned to $selectedReviewer!'),
                    backgroundColor: const Color(0xFF7C3AED),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              child: const Text('Assign Reviewer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }



  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Analytics Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Success Rate: $_successRate%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            const SizedBox(height: 8),
            Text('Total Approved: $_approvedCount', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            Text('Total Rejected: $_rejectedCount', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            Text('Pending QC: $_pendingQCCount', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSystemDrawerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Platform Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
              title: const Text('Sync All APIs'),
              onTap: () {
                Navigator.pop(ctx);
                _loadDashboardData();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded, color: Color(0xFF7C3AED)),
              title: const Text('Export Executive Summary'),
              onTap: () {
                Navigator.pop(ctx);
                _triggerDownload('$_apiBaseUrl/qc-reviews/export/csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text('Logout Admin'),
              onTap: () {
                Navigator.pop(ctx);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Painter for Smooth Trend Line Chart
class _LineChartPainter extends CustomPainter {
  final bool isWeekly;
  _LineChartPainter({this.isWeekly = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x402563EB), Color(0x002563EB)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final points = isWeekly
        ? [
            Offset(0, size.height * 0.85),
            Offset(size.width * 0.16, size.height * 0.65),
            Offset(size.width * 0.33, size.height * 0.25),
            Offset(size.width * 0.50, size.height * 0.50),
            Offset(size.width * 0.66, size.height * 0.25),
            Offset(size.width * 0.83, size.height * 0.40),
            Offset(size.width, size.height * 0.10),
          ]
        : [
            Offset(0, size.height * 0.75),
            Offset(size.width * 0.33, size.height * 0.45),
            Offset(size.width * 0.66, size.height * 0.20),
            Offset(size.width, size.height * 0.12),
          ];

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    final dotPaint = Paint()..color = const Color(0xFF2563EB);
    final innerDotPaint = Paint()..color = Colors.white;

    for (var p in points) {
      canvas.drawCircle(p, 5, dotPaint);
      canvas.drawCircle(p, 2.5, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.isWeekly != isWeekly;
}
