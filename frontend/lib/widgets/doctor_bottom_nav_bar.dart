import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

/// Doctor module bottom navigation bar.
/// Uses [safeIndex] clamping so that non-tab routes (e.g. Notifications)
/// never trigger the BottomNavigationBar out-of-bounds assertion.
class DoctorBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const DoctorBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/doctor-dashboard');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/doctor-appointments');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/doctor-queue');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/doctor-profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard: clamp to valid range [0, 3] to prevent the Flutter assertion
    // '0 <= currentIndex && currentIndex < items.length' from firing when
    // this widget is accidentally rendered with an out-of-bounds index.
    const int itemCount = 4;
    final int safeIndex = currentIndex.clamp(0, itemCount - 1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.doctorPrimaryColor,
        unselectedItemColor: const Color(0xFF64748B),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_rounded),
            label: 'Appointments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_numbered_rounded),
            label: 'Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
