import 'package:flutter/material.dart';

class StaffBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const StaffBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/staff-dashboard');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/opd-queue');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/qr-scanner');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/check-in');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/staff-profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        currentIndex: currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0284C7),
        unselectedItemColor: const Color(0xFF64748B),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_numbered_rounded),
            label: "Queue",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner_rounded),
            label: "Scan QR",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg_rounded),
            label: "Check-In",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.badge_outlined),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
