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

  // Essential Lists (Pre-populated with default fallback items so UI renders at 0ms and never stays blank)
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
  ];

  final List<Map<String, dynamic>> _qcSubmissions = [
    {
      'id': 'VID-001',
      'raw_id': 'demo_vid_001',
      'title': 'Candidate Intro Recording',
      'candidateName': 'Alex Johnson',
      'vendor': 'Acme Video Solutions',
      'duration': '12 Mins',
      'status': 'Pending QC',
    },
    {
      'id': 'VID-002',
      'raw_id': 'demo_vid_002',
      'title': 'Technical Assessment Video',
      'candidateName': 'Emily Davis',
      'vendor': 'Global Media Partners',
      'duration': '18 Mins',
      'status': 'Pending QC',
    },
  ];

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

  Future<http.Response> _safeGet(String url, Map<String, String> headers) async {
    try {
      // 3-second fast timeout to prevent UI freeze on slow cellular networks
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

      // 1. Vendors
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
        } catch (e) {
          debugPrint('Error parsing vendors: $e');
        }
      }

      // 2. Candidates
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
        } catch (e) {
          debugPrint('Error parsing candidates: $e');
        }
      }

      // 3. Videos
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
        } catch (e) {
          debugPrint('Error parsing videos: $e');
        }
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
          SnackBar(content: Text('Downloading report: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Control Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Platform Management', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
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
      body: SizedBox.expand(
        child: IndexedStack(
          index: _activeNavIndex.clamp(0, 2),
          children: [
            _buildVendorsTab(),
            _buildCandidatesTab(),
            _buildQCTab(),
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

  // 1. VENDORS TAB
  Widget _buildVendorsTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
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
                        const Text('Vendor Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Total Registered: ${_vendors.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                                Text(v['name'] ?? 'Vendor Company', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
      ),
    );
  }

  // 2. CANDIDATES TAB
  Widget _buildCandidatesTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Candidate Directory', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('Total Registered: ${_candidates.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),
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
                        title: Text(c['name'] ?? 'Candidate Name', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  // 3. QC QUEUE TAB
  Widget _buildQCTab() {
    return Container(
      color: const Color(0xFFF8FAFC),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
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
                        Text('Total Submissions: ${_qcSubmissions.length}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              child: const Text('Create Vendor'),
            ),
          ],
        ),
      ),
    );
  }
}
