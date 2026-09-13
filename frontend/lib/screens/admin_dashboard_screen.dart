import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/admin_service.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Timer? _timer;
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchDashboardData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final res = await AdminService.getDashboardStats();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _dashboardData = res['data'];
          _errorMessage = null;
        } else {
          _errorMessage = res['message'];
        }
      });
    }
  }

  Future<void> _openBookAppointment() async {
    await Navigator.pushNamed(context, '/book-appointment');
  }

  Future<void> _openUserManagement() async {
    await Navigator.pushNamed(context, '/admin/users');
  }

  Future<void> _openAppointmentManagement() async {
    await Navigator.pushNamed(context, '/admin/appointments');
  }

  Future<void> _openMedicalRecords() async {
    await Navigator.pushNamed(context, '/medical-records');
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Admin';
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
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.local_hospital, color: AppTheme.primaryTeal),
            ),
            const SizedBox(width: 10),
            const Text(
              'MediQ Admin Portal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
      ),

      // Navigation Drawer (Same as Home)
      drawer: Drawer(
        child: Column(
          children: [
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
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              accountName: Text(
                fullName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text('NIC: $nic | Phone: $phone'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded,
                  color: AppTheme.primaryTeal),
              title: const Text('My Profile',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined,
                  color: AppTheme.primaryTeal),
              title: const Text('Dashboard',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: const Text(
                'Logout Account',
                style: TextStyle(
                    color: AppTheme.errorRed, fontWeight: FontWeight.bold),
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

      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Glassmorphism Welcome Card (Adapted for Admin)
              _build3DGlassmorphicWelcomeCard(
                fullName: fullName,
                nic: nic,
                phone: phone,
                bloodGroup: bloodGroup,
                district: district,
                onTapProfile: () => Navigator.pushNamed(context, '/profile'),
              ),
              const SizedBox(height: 20),

              // ADMIN DASHBOARD SECTION
              const Text(
                'OPD ADMIN DASHBOARD',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red))
              else if (_dashboardData != null)
                _buildDashboardContent(_dashboardData!),

              const SizedBox(height: 24),

              // OPD Services Grid (Same as Home)
              const Text(
                'OPD Services',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _build3DGlassCard(
                    icon: Icons.confirmation_number_outlined,
                    title: 'User Management',
                    subtitle: 'Manage patient and user accounts',
                    gradientColors: [
                      const Color(0xFF0077B6),
                      const Color(0xFF0096C7)
                    ],
                    onTap: _openUserManagement,
                  ),
                  _build3DGlassCard(
                    icon: Icons.event_note_outlined,
                    title: 'Doctor & Staff Management',
                    subtitle: 'Manage doctor and staff information',
                    gradientColors: [
                      const Color(0xFF00A896),
                      const Color(0xFF02C39A)
                    ],
                    onTap: _openBookAppointment,
                  ),
                  _build3DGlassCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Queue Management',
                    subtitle: 'Monitor and manage patient queues',
                    gradientColors: [
                      const Color(0xFF0284C7),
                      const Color(0xFF38BDF8)
                    ],
                    onTap: _openMedicalRecords,
                  ),
                  _build3DGlassCard(
                    icon: Icons.contact_support_outlined,
                    title: 'Appointment Management',
                    subtitle: 'Manage patient appointments',
                    gradientColors: [
                      const Color(0xFFE11D48),
                      const Color(0xFFF43F5E)
                    ],
                    onTap: _openAppointmentManagement,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(Map<String, dynamic> data) {
    return Column(
      children: [
        // Top Stats Grid
        Row(
          children: [
            Expanded(
                child: _buildStatCard('Today\'s Patients',
                    data['today_patients'].toString(), Colors.blue)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Appointments',
                    data['appointments_today'].toString(), Colors.purple)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _buildStatCard('Waiting Patients',
                    data['waiting_patients'].toString(), Colors.orange)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard('Completed',
                    data['completed_patients'].toString(), Colors.green)),
          ],
        ),
        const SizedBox(height: 20),

        // Current Queues
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CURRENT QUEUES',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              ...((data['queues'] as Map<String, dynamic>).entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 15)),
                      Text('${entry.value} waiting',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                );
              })),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // High Waiting Time
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('High Waiting Time',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red)),
                ],
              ),
              const Divider(color: Colors.red),
              ...((data['high_waiting_time'] as List<dynamic>).map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry['room'],
                          style:
                              const TextStyle(fontSize: 15, color: Colors.red)),
                      Text(entry['time'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.red)),
                    ],
                  ),
                );
              })),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13, color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

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
              Color(0xFF6B7280), // Gray for admin
              Color(0xFF374151),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF374151).withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName,
                          style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('NIC: $nic | Phone: $phone',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderTag('Role', 'ADMIN'),
                _buildHeaderTag('Access Level', 'Full Access'),
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
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ],
    );
  }

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
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText)),
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
          ],
        ),
      ),
    );
  }
}
