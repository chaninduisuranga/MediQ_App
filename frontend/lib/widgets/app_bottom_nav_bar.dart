import 'package:flutter/material.dart';
import '../core/services/language_service.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/book-appointment');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/medical-records');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLang, _) {
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
            selectedItemColor: const Color(0xFF2563EB),
            unselectedItemColor: const Color(0xFF94A3B8),
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            backgroundColor: Colors.white,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                label: LanguageService.tr('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month_rounded),
                label: LanguageService.tr('nav_appointments'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.folder_open_rounded),
                label: LanguageService.tr('nav_records'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded),
                label: LanguageService.tr('nav_profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
