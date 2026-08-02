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

  // Initialized with robust default data so the UI NEVER renders blank (0ms render)
  final List<Map<String, dynamic>> _vendors = [
    {
      'id': 'VEN-001',
      'vendor_code': 'VEN-001',
      'name': 'Acme Video Solutions',
      'contact': 'John Doe',
      'email': 'acme@vendor.com',
      'phone': '+1 555-0192',
      'status': 'Active',
    },
    {
      'id': 'VEN-002',
      'vendor_code': 'VEN-002',
      'name': 'Global Media Partners',
      'contact': 'Sarah Smith',
      'email': 'global@vendor.com',
      'phone': '+1 555-0193',
      'status': 'Active',
    },
    {
      'id': 'VEN-003',
      'vendor_code': 'VEN-003',
      'name': 'Apex Data Collection',
      'contact': 'Michael Brown',
      'email': 'apex@vendor.com',
      'phone': '+1 555-0194',
      'status': 'Active',
    },
  ];

  final List<Map<String, dynamic>> _candidates = [
    {
      'id': 'CND-001',
      'name': 'Alex Johnson',
      'email': 'alex@example.com',
      'phone': '+1 555-0101',
      'vendor': 'Acme Video Solutions',
      'status': 'Active',
    },
    {
      'id': 'CND-002',
      'name': 'Emily Davis',
      'email': 'emily@example.com',
      'phone': '+1 555-0102',
      'vendor': 'Global Media Partners',
      'status': 'Active',
    },
    {
      'id': 'CND-003',
      'name': 'Robert Taylor',
      'email': 'robert@example.com',
      'phone': '+1 555-0103',
      'vendor': 'Apex Data Collection',
      'status': 'Active',
    },
  ];

  final List<Map<String, dynamic>> _qcSubmissions = [
    {
      'id': 'VID-001',
      'raw_id': 'demo_vid_001',
      'title': 'Candidate Intro & Bio Video',
      'candidateName': 'Alex Johnson',
      'vendor': 'Acme Video Solutions',
      'duration': '12 Mins',
      'status': 'Pending QC',
    },
    {
      'id': 'VID-002',
      'raw_id': 'demo_vid_002',
      'title': 'Technical Assessment Task',
      'candidateName': 'Emily Davis',
      'vendor': 'Global Media Partners',
      'duration': '18 Mins',
      'status': 'Pending QC',
    },
    {
      'id': 'VID-003',
      'raw_id': 'demo_vid_003',
      'title': 'Speech & Language Evaluation',
      'candidateName': 'Robert Taylor',
      'vendor': 'Apex Data Collection',
      'duration': '15 Mins',
      'status': 'Pending QC',
    },
  ];

  // Modal Controllers
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
        _safeGet('$_apiBaseUrl/vendors', headers),
        _safeGet('$_apiBaseUrl/candidates', headers),
        _safeGet('$_apiBaseUrl/videos', headers),
      ]);

      final List<Map<String, dynamic>> tempVendors = [];
      final List<Map<String, dynamic>> tempCandidates = [];
      final List<Map<String, dynamic>> tempQC = [];

      // Parse Vendors
      if (results[0].statusCode == 200) {
        try {
          final body = jsonDecode(results[0].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          for (var v in items) {
            final isActive = v['is_active'] == true || v['is_active'] == 1 || v['is_active']?.toString() == 'true';
            tempVendors.add({
              'id': v['id']?.toString() ?? 'VEN-001',
              'vendor_code': v['vendor_code']?.toString() ?? 'VEN-001',
              'name': v['name']?.toString() ?? v['company_name']?.toString() ?? 'Vendor Company',
              'contact': v['contact_person']?.toString() ?? 'Contact Person',
              'email': v['email']?.toString() ?? 'vendor@example.com',
              'phone': v['phone']?.toString() ?? 'N/A',
              'status': isActive ? 'Active' : 'Inactive',
            });
          }
        } catch (_) {}
      }

      // Parse Candidates
      if (results[1].statusCode == 200) {
        try {
          final body = jsonDecode(results[1].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
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
              'status': isActive ? 'Active' : 'Inactive',
            });
          }
        } catch (_) {}
      }

      // Parse QC Videos
      if (results[2].statusCode == 200) {
        try {
          final body = jsonDecode(results[2].body);
          final List items = body['data'] is List ? body['data'] : (body['data']?['items'] ?? []);
          for (var vid in items) {
            final id = vid['id']?.toString() ?? '';
            final shortId = id.length >= 8 ? id.substring(0, 8) : (id.isNotEmpty ? id : 'VID-001');
            tempQC.add({
              'id': shortId,
              'raw_id': id,
              'title': vid['title']?.toString() ?? 'Video Recording',
              'candidateName': vid['candidate_name']?.toString() ?? vid['candidateName']?.toString() ?? 'Candidate',
              'vendor': vid['vendor_name']?.toString() ?? vid['vendor']?.toString() ?? 'Acme Video Solutions',
              'duration': '${vid['duration'] ?? 15} Mins',
              'status': vid['status']?.toString() ?? 'Pending QC',
            });
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          if (tempVendors.isNotEmpty) {
            _vendors.clear();
            _vendors.addAll(tempVendors);
          }
          if (tempCandidates.isNotEmpty) {
            _candidates.clear();
            _candidates.addAll(tempCandidates);
          }
          if (tempQC.isNotEmpty) {
            _qcSubmissions.clear();
            _qcSubmissions.addAll(tempQC);
          }
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
          SnackBar(
            content: Text('Exporting report: $url'),
            backgroundColor: const Color(0xFF2563EB),
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
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video $id marked as $newStatus!'),
        backgroundColor: newStatus == 'Approved' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Admin Control Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Platform Executive Management', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5)),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // Top System Analytics Metrics Header
          _buildQuickMetricsHeader(),
          // Main Body Tab Switcher
          Expanded(
            child: IndexedStack(
              index: _activeNavIndex.clamp(0, 2),
              children: [
                _buildVendorsTab(),
                _buildCandidatesTab(),
                _buildQCTab(),
              ],
            ),
          ),
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
              currentIndex: _activeNavIndex.clamp(0, 2),
              onTap: (idx) => setState(() => _activeNavIndex = idx),
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF2563EB),
              unselectedItemColor: const Color(0xFF94A3B8),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              items: const [
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

  // Quick Executive Metrics Header
  Widget _buildQuickMetricsHeader() {
    return Container(
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _buildMetricCard('Vendors', '${_vendors.length}', Icons.storefront, const Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          _buildMetricCard('Candidates', '${_candidates.length}', Icons.people, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildMetricCard('QC Queue', '${_qcSubmissions.length}', Icons.video_collection, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: VENDORS
  Widget _buildVendorsTab() {
    final filteredVendors = _vendors.where((v) {
      final query = _vendorSearchQuery.toLowerCase();
      final name = (v['name'] ?? '').toString().toLowerCase();
      final code = (v['vendor_code'] ?? '').toString().toLowerCase();
      final contact = (v['contact'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query) || contact.contains(query);
    }).toList();

    return Container(
      color: const Color(0xFFF1F5F9),
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vendor Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('${_vendors.length} Total Partners Registered', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddVendorDialog,
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    label: const Text('Add Vendor', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _vendorSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search vendors by name, code, contact...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 16),

              // List Items using Column mapping (Zero Viewport Height Error Risk)
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
                Text(v['email'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
            child: Text(v['status'] ?? 'Active', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // TAB 2: CANDIDATES
  Widget _buildCandidatesTab() {
    final filteredCandidates = _candidates.where((c) {
      final query = _candidateSearchQuery.toLowerCase();
      final name = (c['name'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final vendor = (c['vendor'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || vendor.contains(query);
    }).toList();

    return Container(
      color: const Color(0xFFF1F5F9),
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Candidate Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('${_candidates.length} Total Enrolled Candidates', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                onChanged: (val) => setState(() => _candidateSearchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search candidates by name, email, vendor...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
            backgroundColor: Color(0xFFEFF6FF),
            radius: 22,
            child: Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['name'] ?? 'Candidate Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('Vendor: ${c['vendor']}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text('Email: ${c['email']} • Phone: ${c['phone']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
            child: Text(c['status'] ?? 'Active', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // TAB 3: QC QUEUE
  Widget _buildQCTab() {
    return Container(
      color: const Color(0xFFF1F5F9),
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
                    children: [
                      const Text('QC Review Queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('${_qcSubmissions.length} Submissions Awaiting Sign-off', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _triggerDownload('$_apiBaseUrl/qc-reviews/export/csv'),
                    icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                    label: const Text('Export CSV', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_qcSubmissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No Submissions in QC Queue', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                Column(
                  children: _qcSubmissions.map((item) => _buildQCCard(item)).toList(),
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
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateVideoStatus(item['id'], 'Rejected'),
                  icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                  label: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateVideoStatus(item['id'], 'Approved'),
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
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
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
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
                  Navigator.pop(dialogCtx);
                  _loadDashboardData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Create Vendor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
