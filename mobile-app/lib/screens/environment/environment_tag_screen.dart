import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';

class EnvironmentTagItem {
  final String label;
  final IconData icon;
  final Color color;

  const EnvironmentTagItem({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class EnvironmentTagScreen extends StatefulWidget {
  const EnvironmentTagScreen({super.key});

  @override
  State<EnvironmentTagScreen> createState() => _EnvironmentTagScreenState();
}

class _EnvironmentTagScreenState extends State<EnvironmentTagScreen> {
  static const List<EnvironmentTagItem> _tags = [
    EnvironmentTagItem(
      label: 'Kitchen',
      icon: Icons.kitchen_rounded,
      color: Color(0xFFF97316), // Orange
    ),
    EnvironmentTagItem(
      label: 'Bedroom',
      icon: Icons.bed_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
    EnvironmentTagItem(
      label: 'Bathroom',
      icon: Icons.bathtub_rounded,
      color: Color(0xFF0EA5E9), // Sky Blue
    ),
    EnvironmentTagItem(
      label: 'Garden',
      icon: Icons.local_florist_rounded,
      color: Color(0xFF10B981), // Emerald Green
    ),
    EnvironmentTagItem(
      label: 'Office',
      icon: Icons.work_rounded,
      color: Color(0xFF6366F1), // Indigo
    ),
    EnvironmentTagItem(
      label: 'Others',
      icon: Icons.category_rounded,
      color: Color(0xFF64748B), // Slate Grey
    ),
  ];

  String? _selectedTag;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTag();
  }

  Future<void> _loadSavedTag() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_environment_tag');
    if (saved != null && mounted) {
      setState(() {
        _selectedTag = saved;
      });
    }
  }

  Future<void> _saveSelectedTag() async {
    if (_selectedTag == null) return;

    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_environment_tag', _selectedTag!);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Environment tag '$_selectedTag' saved locally!"),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      if (Navigator.canPop(context) && ModalRoute.of(context)?.willHandlePopInternally == true) {
        Navigator.pop(context, _selectedTag);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.cameraPermission);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Environment Tag'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Instructions
              Text(
                'Where is this video being recorded?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please select one environment tag for dataset categorization.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 24),

              // Grid of Environment Options
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    final isSelected = _selectedTag == tag.label;

                    return _buildTagCard(
                      tag: tag,
                      isSelected: isSelected,
                      isDarkMode: isDarkMode,
                      onTap: () {
                        setState(() {
                          _selectedTag = tag.label;
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Button
              ElevatedButton.icon(
                onPressed: _selectedTag != null && !_isSaving ? _saveSelectedTag : null,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  _selectedTag != null
                      ? 'Confirm "$_selectedTag"'
                      : 'Select an Environment Tag',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedTag != null ? AppColors.primary : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagCard({
    required EnvironmentTagItem tag,
    required bool isSelected,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? tag.color.withAlpha(30)
              : (isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? tag.color
                : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tag.color.withAlpha(50),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: tag.color.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tag.icon,
                    size: 28,
                    color: tag.color,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: tag.color,
                    size: 22,
                  ),
              ],
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tag.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? tag.color
                      : (isDarkMode
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
