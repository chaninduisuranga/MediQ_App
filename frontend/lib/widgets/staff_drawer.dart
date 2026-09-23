import 'dart:io';
import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';

class StaffDrawer extends StatelessWidget {
  final String currentRoute;

  const StaffDrawer({
    super.key,
    required this.currentRoute,
  });

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 26),
            SizedBox(width: 10),
            Text('Logout Confirmation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from the Staff Portal?',
          style: TextStyle(fontSize: 14, color: AppTheme.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.logout();
              Navigator.pushNamedAndRemoveUntil(
                  context, AppRoutes.login, (route) => false);
            },
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String routeName) {
    Navigator.pop(context); // Close drawer
    if (currentRoute == routeName) return;
    Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final fullName = user?['full_name'] as String? ?? 'Chaminda Bandara';
    final nic = user?['nic'] as String? ?? 'STF-8842';

    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // 1. Ultra-Modern Header Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330284C7),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar Ring
                    ValueListenableBuilder<String?>(
                      valueListenable: AuthService.profilePhotoNotifier,
                      builder: (context, photoPath, _) {
                        final hasPhoto = photoPath != null &&
                            photoPath.isNotEmpty &&
                            File(photoPath).existsSync();
                        return Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF38BDF8),
                                Color(0xFF818CF8),
                                Color(0xFFC084FC)
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8)
                                    .withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: hasPhoto
                                  ? Image.file(
                                      File(photoPath),
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    )
                                  : Text(
                                      fullName.isNotEmpty
                                          ? fullName[0].toUpperCase()
                                          : 'S',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primarySkyBlue,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4ADE80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'STAFF: $nic',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Scrollable Menu Categories
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
                  child: Text(
                    'STAFF MANAGEMENT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Dashboard
                _buildDrawerTile(
                  icon: Icons.dashboard_rounded,
                  iconGradientColors: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                  title: 'Dashboard',
                  isSelected: currentRoute == AppRoutes.staffDashboard,
                  onTap: () => _navigate(context, AppRoutes.staffDashboard),
                ),

                // Queue Management
                _buildDrawerTile(
                  icon: Icons.format_list_numbered_rounded,
                  iconGradientColors: const [Color(0xFF0284C7), Color(0xFF0077B6)],
                  title: 'Queue Management',
                  isSelected: currentRoute == AppRoutes.opdQueue,
                  onTap: () => _navigate(context, AppRoutes.opdQueue),
                ),

                // Doctor Allocation
                _buildDrawerTile(
                  icon: Icons.medical_services_rounded,
                  iconGradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                  title: 'Doctor Allocation',
                  badge: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'OPD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  isSelected: currentRoute == AppRoutes.doctorAllocation,
                  onTap: () => _navigate(context, AppRoutes.doctorAllocation),
                ),

                // Scan QR
                _buildDrawerTile(
                  icon: Icons.qr_code_scanner_rounded,
                  iconGradientColors: const [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                  title: 'Scan QR Ticket',
                  isSelected: currentRoute == AppRoutes.qrScanner,
                  onTap: () => _navigate(context, AppRoutes.qrScanner),
                ),

                // Patient Check-In
                _buildDrawerTile(
                  icon: Icons.how_to_reg_rounded,
                  iconGradientColors: const [Color(0xFF0284C7), Color(0xFF00A896)],
                  title: 'Patient Check-In',
                  isSelected: currentRoute == AppRoutes.checkIn,
                  onTap: () => _navigate(context, AppRoutes.checkIn),
                ),

                // Queue History
                _buildDrawerTile(
                  icon: Icons.history_rounded,
                  iconGradientColors: const [Color(0xFF64748B), Color(0xFF475569)],
                  title: 'Queue History',
                  isSelected: currentRoute == AppRoutes.queueHistory,
                  onTap: () => _navigate(context, AppRoutes.queueHistory),
                ),

                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 16, bottom: 8),
                  child: Text(
                    'ACCOUNT & ALERTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Notifications & Alerts
                _buildDrawerTile(
                  icon: Icons.notifications_active_rounded,
                  iconGradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  title: 'Notifications & Alerts',
                  isSelected: currentRoute == AppRoutes.staffNotifications,
                  onTap: () => _navigate(context, AppRoutes.staffNotifications),
                ),

                // Staff Profile
                _buildDrawerTile(
                  icon: Icons.badge_outlined,
                  iconGradientColors: const [Color(0xFF0284C7), Color(0xFF0284C7)],
                  title: 'Staff Profile',
                  isSelected: currentRoute == AppRoutes.staffProfile,
                  onTap: () => _navigate(context, AppRoutes.staffProfile),
                ),
              ],
            ),
          ),

          // 3. Modern Red-Tinted Logout Footer Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleLogout(context),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.errorRed.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppTheme.errorRed, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Logout from Staff Portal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required List<Color> iconGradientColors,
    required String title,
    required bool isSelected,
    Widget? badge,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? AppTheme.primarySkyBlue.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iconGradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradientColors.first.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primarySkyBlue
                          : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
