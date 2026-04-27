import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'doctor_chat_list_screen.dart';
import 'doctor_appointments_screen.dart';
import 'doctor_profile_screen.dart';
import '../donations/donation_feed_screen.dart';

/// واجهة الطبيب داخل نفس التطبيق — يُفعّل عندما `users/{uid}.role == doctor`
class DoctorHomeShell extends StatefulWidget {
  final String userName;
  final VoidCallback toggleTheme;
  final bool isDark;

  const DoctorHomeShell({
    super.key,
    required this.userName,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<DoctorHomeShell> createState() => _DoctorHomeShellState();
}

class _DoctorHomeShellState extends State<DoctorHomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isArabic = Directionality.of(context) == TextDirection.rtl;

    final List<Widget> screens = [
      const DoctorChatListScreen(),
      const DoctorAppointmentsScreen(),
      DoctorProfileScreen(
        userName: widget.userName,
        toggleTheme: widget.toggleTheme,
        isDark: widget.isDark,
      ),
    ];

    return Scaffold(
      backgroundColor: widget.isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: _selectedIndex != 2 // Hide AppBar for Profile tab as it has its own padding/style
          ? AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              centerTitle: false,
              title: Text(
                isArabic 
                    ? (_selectedIndex == 0 ? 'المحادثات' : 'المواعيد الجارية')
                    : (_selectedIndex == 0 ? 'Messages' : 'Appointments'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              actions: [
                // Direct Donation Link in AppBar
                IconButton(
                  icon: const Icon(Icons.volunteer_activism_rounded, color: Color(0xFF10B981)),
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const DonationFeedScreen()),
                  ),
                  tooltip: isArabic ? 'تبرعات المجتمع' : 'Community Donations',
                ),
                // Direct Profile Link in AppBar
                IconButton(
                  icon: const Icon(Icons.person_pin_rounded),
                  onPressed: () => setState(() => _selectedIndex = 2),
                  tooltip: isArabic ? 'الملف الشخصي' : 'Profile',
                ),
                if (_selectedIndex != 2)
                  IconButton(
                    icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                    onPressed: widget.toggleTheme,
                    tooltip: isArabic ? 'الوضع' : 'Theme',
                  ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                  tooltip: isArabic ? 'خروج' : 'Sign out',
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFF10B981),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: const Icon(Icons.chat_bubble_rounded),
              label: isArabic ? 'المحادثات' : 'Chats',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today_outlined),
              activeIcon: const Icon(Icons.calendar_today_rounded),
              label: isArabic ? 'المواعيد' : 'Appointments',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline_rounded),
              activeIcon: const Icon(Icons.person_rounded),
              label: isArabic ? 'الملف الشخصي' : 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
