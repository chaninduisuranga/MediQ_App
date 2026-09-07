import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Patient';
    final nic = user['nic'] ?? 'N/A';
    final phone = user['phone'] ?? 'N/A';
    final bloodGroup = user['blood_group'] ?? 'N/A';
    final district = user['district'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              tooltip: 'Open Menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              errorBuilder: (_, __, ___) => const Icon(Icons.local_hospital, color: AppTheme.primaryTeal),
            ),
            const SizedBox(width: 10),
            const Text(
              'MediQ OPD Portal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),

      // Modern Navigation Drawer (Sidebar)
      drawer: Drawer(
        child: Column(
          children: [
            // Glassmorphic Drawer Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              accountName: Text(
                fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text('NIC: $nic | Phone: $phone'),
            ),

            // Sidebar Menu Links
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryTeal),
              title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryTeal),
              title: const Text('OPD Live Queue', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('OPD Live Queue feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined, color: AppTheme.primaryTeal),
              title: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appointment booking feature coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services_outlined, color: AppTheme.primaryTeal),
              title: const Text('Medical Records & History', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Medical history coming soon!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFFEF4444)),
              title: const Text('Emergency SOS (1990)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling Suwa Seriya 1990 Emergency Hotline...')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppTheme.mutedText),
              title: const Text('App Information', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'MediQ OPD Portal',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Government OPD - Closer to You',
                );
              },
            ),

            const Spacer(),
            const Divider(),

            // Logout Option at Bottom of Sidebar
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: const Text(
                'Logout Account',
                style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3D Glassmorphism Welcome Card
            _build3DGlassmorphicWelcomeCard(
              fullName: fullName,
              nic: nic,
              phone: phone,
              bloodGroup: bloodGroup,
              district: district,
              onTapProfile: () => Navigator.pushNamed(context, '/profile'),
            ),

            const SizedBox(height: 28),

            const Text(
              'OPD Services',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),

            // 3D Glassmorphism Grid Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _build3DGlassCard(
                  icon: Icons.confirmation_number_outlined,
                  title: 'OPD Live Queue',
                  subtitle: 'Check live token status',
                  gradientColors: [const Color(0xFF0077B6), const Color(0xFF0096C7)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OPD Live Queue feature coming soon!')),
                    );
                  },
                ),
                _build3DGlassCard(
                  icon: Icons.event_note_outlined,
                  title: 'Book Appointment',
                  subtitle: 'Schedule OPD Visit',
                  gradientColors: [const Color(0xFF00A896), const Color(0xFF02C39A)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appointment booking feature coming soon!')),
                    );
                  },
                ),
                _build3DGlassCard(
                  icon: Icons.medical_services_outlined,
                  title: 'Medical Records',
                  subtitle: 'Prescriptions & History',
                  gradientColors: [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medical history feature coming soon!')),
                    );
                  },
                ),
                _build3DGlassCard(
                  icon: Icons.contact_support_outlined,
                  title: 'Emergency 1990',
                  subtitle: 'Suwa Seriya Ambulance',
                  gradientColors: [const Color(0xFFE11D48), const Color(0xFFF43F5E)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emergency Hotline: Dial 1990')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 3D Glassmorphism Welcome Card Widget
  Widget _build3DGlassmorphicWelcomeCard({
    required String fullName,
    required String nic,
    required String phone,
    required String bloodGroup,
    required String district,
    required VoidCallback onTapProfile,
  }) {
    return GestureDetector(
      onTap: onTapProfile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0077B6),
              Color(0xFF00A896),
              Color(0xFF02C39A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A896).withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NIC: $nic | Phone: $phone',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderTag('Blood Group', bloodGroup),
                _buildHeaderTag('District', district),
                _buildHeaderTag('Role', 'PATIENT'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTag(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // 3D Glassmorphism OPD Grid Card Widget
  Widget _build3DGlassCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: gradientColors.first.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
