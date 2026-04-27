import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../donations/donation_feed_screen.dart';
import '../../language_config.dart';

class DoctorProfileScreen extends StatefulWidget {
  final String userName;
  final VoidCallback toggleTheme;
  final bool isDark;

  const DoctorProfileScreen({
    super.key,
    required this.userName,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }

  Future<void> _loadDoctorData() async {
    final userData = await AuthService().getUserData();
    if (mounted) {
      setState(() {
        _isVerified = userData?['isVerified'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                          child: Icon(Icons.person_rounded, size: 50, color: const Color(0xFF10B981)),
                        ),
                        if (_isVerified)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.userName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      isArabic ? 'طبيب متخصص' : 'Specialist Doctor',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Community Section
              _buildSectionHeader(isArabic ? 'إدارة المجتمع' : 'Community Management', isDark),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildProfileOption(
                  Icons.verified_user_rounded,
                  isArabic ? 'تبرعات المجتمع' : 'Community Donations',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DonationFeedScreen()),
                  ),
                  isDark: isDark,
                  color: const Color(0xFF3B82F6),
                  trailing: _isVerified ? Icon(Icons.verified_rounded, color: Colors.blue[400], size: 20) : null,
                ),
              ], isDark),

              const SizedBox(height: 30),

              // Account Settings
              _buildSectionHeader(isArabic ? 'الإعدادات' : 'Settings', isDark),
              const SizedBox(height: 12),
              _buildSettingsCard([
                _buildProfileOption(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  isArabic ? (isDark ? 'الوضع الفاتح' : 'الوضع الليلي') : (isDark ? 'Light Mode' : 'Dark Mode'),
                  widget.toggleTheme,
                  isDark: isDark,
                  color: const Color(0xFFF59E0B),
                ),
                _buildProfileOption(
                  Icons.logout_rounded,
                  isArabic ? 'تسجيل الخروج' : 'Logout',
                  () => AuthService().signOut(),
                  isDark: isDark,
                  color: Colors.redAccent,
                  showArrow: false,
                ),
              ], isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String title,
    VoidCallback onTap, {
    required bool isDark,
    required Color color,
    Widget? trailing,
    bool showArrow = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            if (showArrow)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.grey[600] : Colors.grey[300],
              ),
          ],
        ),
      ),
    );
  }
}
