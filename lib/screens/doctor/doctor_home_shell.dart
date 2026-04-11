import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'doctor_chat_list_screen.dart';
import 'doctor_appointments_screen.dart';

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
    ];

    return Scaffold(
      backgroundColor: widget.isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          isArabic 
              ? (_selectedIndex == 0 ? 'محادثات — ${widget.userName}' : 'مواعيـدي')
              : (_selectedIndex == 0 ? 'Chats — ${widget.userName}' : 'My Appointments'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
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
        ],
      ),
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
          ],
        ),
      ),
    );
  }
}
