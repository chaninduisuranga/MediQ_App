import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';
import '../widgets/doctor_bottom_nav_bar.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
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
          'Are you sure you want to log out of the Doctor Portal?',
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

  void _showActionSnackbar(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title feature selected.'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.doctorPrimaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final doctorName = user['full_name'] ?? 'Doctor Name';
    final doctorId = user['nic'] ?? 'DOC-1029'; // Mock ID if not available
    final specialization = user['specialization'] ?? user['department'] ?? 'General Physician';
    final email = user['email'] ?? 'doctor@mediq.lk';
    final phone = user['phone'] ?? '+94 77 123 4567';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Doctor Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
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
                            AppTheme.doctorPrimaryColor.withValues(alpha: 0.15),
                        child: const Icon(
                          Icons.medical_services_rounded,
                          size: 50,
                          color: AppTheme.doctorPrimaryColor,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.doctorPrimaryColor,
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
                    'Dr. $doctorName',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$specialization | ID: $doctorId',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.mutedText,
                        fontWeight: FontWeight.w500),
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
                    'Contact & Professional Info',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const Divider(height: 20),
                  _buildProfileInfoRow(
                      Icons.email_outlined, 'Email', email),
                  _buildProfileInfoRow(
                      Icons.phone_outlined, 'Phone', phone),
                  _buildProfileInfoRow(
                      Icons.domain_rounded, 'Department', specialization),
                  _buildProfileInfoRow(Icons.meeting_room_outlined,
                      'Default OPD', 'General OPD'),
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
                    icon: Icons.event_available_rounded,
                    title: 'My Availability',
                    subtitle: 'Manage schedule and active status',
                    onTap: () => Navigator.pushNamed(context, '/doctor-availability'),
                  ),
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.edit_note_rounded,
                    title: 'Edit Profile',
                    subtitle: 'Update contact details & bio',
                    onTap: () => _showActionSnackbar('Edit Profile'),
                  ),
                  const Divider(height: 1),
                  _buildActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change Password',
                    subtitle: 'Update account security settings',
                    onTap: () => _showActionSnackbar('Change Password'),
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
                  'LOGOUT FROM DOCTOR PORTAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DoctorBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.doctorPrimaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
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
        child: Icon(icon, color: AppTheme.doctorPrimaryColor, size: 22),
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
