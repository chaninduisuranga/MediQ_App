import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  bool _isOnDuty = true;
  final String _staffName = 'Chaminda Bandara';
  final String _staffId = 'STF-8842';
  final String _role = 'Senior OPD Staff';
  final String _department = 'Outpatient Department (OPD)';
  final String _assignedOpd = 'General OPD / Dressing Room';
  final String _shift = 'Morning Shift (08:00 AM - 04:00 PM)';

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorRed),
            SizedBox(width: 10),
            Text('Logout Confirmation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of the Staff Portal?',
          style: TextStyle(fontSize: 14, color: AppTheme.mutedText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.logout();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.staffProfile),
      appBar: AppBar(
        title: const Text(
          'Staff Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Queue History',
            onPressed: () => Navigator.pushNamed(context, '/queue-history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor:
                            AppTheme.primarySkyBlue.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 56,
                          color: AppTheme.primarySkyBlue,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primarySkyBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _staffName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_role | ID: $_staffId',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.mutedText,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 14),

                  // On-Duty Status Switch Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          _isOnDuty ? AppTheme.lightBg : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isOnDuty
                            ? AppTheme.primarySkyBlue.withValues(alpha: 0.3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _isOnDuty ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _isOnDuty ? 'ON DUTY (Active Queue)' : 'OFF DUTY',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _isOnDuty
                                    ? AppTheme.primarySkyBlue
                                    : AppTheme.mutedText,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnDuty,
                          activeThumbColor: AppTheme.primarySkyBlue,
                          onChanged: (val) {
                            setState(() => _isOnDuty = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Duty & Shift Info Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Staff Assignment & Shift',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                      Icons.domain_rounded, 'Department', _department),
                  _buildProfileInfoRow(Icons.meeting_room_outlined,
                      'Assigned OPD', _assignedOpd),
                  _buildProfileInfoRow(
                      Icons.schedule_rounded, 'Current Shift', _shift),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Action List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.edit_note_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update staff contact details & bio',
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.staffEditProfile),
                  ),
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications & Alerts',
                    subtitle: 'Queue broadcast & announcements',
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.staffNotifications),
                  ),
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update account security settings',
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.staffChangePassword),
                  ),
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.medical_services_rounded,
                    title: 'Doctor Allocation',
                    subtitle: 'Batch allocate General OPD patients',
                    onTap: () => Navigator.pushNamed(
                        context, AppRoutes.doctorAllocation),
                  ),
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.history_rounded,
                    title: 'Activity & Queue History',
                    subtitle: 'View past patient turn actions',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.queueHistory),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _handleLogout,
                icon:
                    const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
                label: const Text(
                  'LOGOUT FROM STAFF PORTAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primarySkyBlue),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.mutedText,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.lightBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primarySkyBlue, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText),
    );
  }
}
