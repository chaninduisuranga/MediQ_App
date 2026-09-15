import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';
import '../widgets/doctor_bottom_nav_bar.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await DoctorService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load dashboard data.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final doctorName = user['full_name'] ?? 'Doctor';
    final specialization = user['specialization'] ?? user['department'] ?? 'General OPD';
    final today = _formatDate(DateTime.now());
    final isAvailable = (_stats['is_available'] as bool?) ?? true;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: CustomScrollView(
          slivers: [
            // ── SliverAppBar with gradient header ──
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppTheme.primarySkyBlue,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: _fetchStats,
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  tooltip: 'Notifications',
                  onPressed: () =>
                      Navigator.pushNamed(context, '/doctor-notifications'),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: const Icon(Icons.medical_services_rounded,
                                color: Colors.white, size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dr. $doctorName',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  specialization,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  today,
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          // Availability Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.greenAccent.withValues(alpha: 0.2)
                                  : Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isAvailable
                                        ? Colors.greenAccent
                                        : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body Content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error Banner
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.errorRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.errorRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(
                                      color: AppTheme.errorRed, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),

                    // ── Stats Section ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Overview",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primarySkyBlue),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Stat Cards Grid — responsive 2-col
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.3,
                          children: [
                            _buildStatCard(
                              title: "Today's Appointments",
                              value: '${_stats['total_today'] ?? 0}',
                              icon: Icons.calendar_today_rounded,
                              color: AppTheme.primarySkyBlue,
                            ),
                            _buildStatCard(
                              title: 'Waiting Patients',
                              value: '${_stats['waiting'] ?? 0}',
                              icon: Icons.hourglass_top_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                            _buildStatCard(
                              title: 'In Consultation',
                              value: '${_stats['in_consultation'] ?? 0}',
                              icon: Icons.medical_services_rounded,
                              color: const Color(0xFF8B5CF6),
                            ),
                            _buildStatCard(
                              title: 'Completed',
                              value: '${_stats['completed'] ?? 0}',
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF10B981),
                            ),
                            _buildStatCard(
                              title: 'Current Queue',
                              value: _stats['current_queue_number'] ?? '--',
                              icon: Icons.confirmation_number_rounded,
                              color: AppTheme.primaryBlue,
                            ),
                            _buildStatCard(
                              title: 'Next Patient',
                              value: _stats['next_queue_number'] ?? '--',
                              icon: Icons.arrow_circle_right_rounded,
                              color: const Color(0xFF0D9488),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Current / Next Patient Banner
                    if ((_stats['current_patient_name'] ?? '--') != '--')
                      _buildPatientBanner(
                        label: 'Currently Consulting',
                        queueNum: _stats['current_queue_number'] ?? '--',
                        name: _stats['current_patient_name'] ?? '--',
                        color: AppTheme.primarySkyBlue,
                        icon: Icons.person_pin_circle_rounded,
                      ),
                    if ((_stats['next_patient_name'] ?? '--') != '--')
                      _buildPatientBanner(
                        label: 'Next Patient',
                        queueNum: _stats['next_queue_number'] ?? '--',
                        name: _stats['next_patient_name'] ?? '--',
                        color: const Color(0xFF0D9488),
                        icon: Icons.person_outline_rounded,
                      ),

                    const SizedBox(height: 28),

                    // ── Quick Actions ──
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 14),

                    _buildNavTile(
                      title: "Today's Appointments",
                      subtitle: 'View all appointments scheduled for today',
                      icon: Icons.calendar_today_rounded,
                      color: AppTheme.primarySkyBlue,
                      onTap: () => Navigator.pushNamed(
                          context, '/doctor-appointments'),
                    ),
                    const SizedBox(height: 10),
                    _buildNavTile(
                      title: 'Manage Queue',
                      subtitle: 'View queue, call next patient, update status',
                      icon: Icons.format_list_numbered_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () =>
                          Navigator.pushNamed(context, '/doctor-queue'),
                    ),
                    const SizedBox(height: 10),
                    _buildNavTile(
                      title: 'Call Next Patient',
                      subtitle: 'Directly call the next waiting patient',
                      icon: Icons.campaign_rounded,
                      color: const Color(0xFFF59E0B),
                      onTap: _showCallNextDialog,
                    ),
                    const SizedBox(height: 10),
                    _buildNavTile(
                      title: 'Previous Appointments',
                      subtitle: 'View consultation history and records',
                      icon: Icons.history_rounded,
                      color: const Color(0xFF0D9488),
                      onTap: () => Navigator.pushNamed(
                          context, '/doctor-previous-appointments'),
                    ),
                    const SizedBox(height: 10),
                    _buildNavTile(
                      title: 'Manage Availability',
                      subtitle: 'Update your availability and session schedule',
                      icon: Icons.event_available_rounded,
                      color: const Color(0xFF10B981),
                      onTap: () =>
                          Navigator.pushNamed(context, '/doctor-availability'),
                    ),
                    const SizedBox(height: 10),
                    _buildNavTile(
                      title: 'My Profile',
                      subtitle: 'View and edit your doctor profile',
                      icon: Icons.person_rounded,
                      color: AppTheme.mutedText,
                      onTap: () =>
                          Navigator.pushNamed(context, '/doctor-profile'),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DoctorBottomNavBar(currentIndex: 0),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Call Next Patient — quick dashboard action
  // ─────────────────────────────────────────────────────────────────────
  void _showCallNextDialog() async {
    final appointments = await DoctorService.getTodayAppointments();
    final waiting = appointments
        .where((a) =>
            a['queue_status'] == 'CHECKED_IN' ||
            a['appointment_status'] == 'WAITING')
        .toList();

    if (!mounted) return;

    if (waiting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients currently waiting in the queue.'),
          backgroundColor: AppTheme.mutedText,
        ),
      );
      return;
    }

    final next = waiting.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded,
                color: AppTheme.primarySkyBlue, size: 26),
            SizedBox(width: 10),
            Text('Call Next Patient',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm calling this patient for consultation:',
                style: TextStyle(fontSize: 13, color: AppTheme.mutedText)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppTheme.primarySkyBlue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    next['queue_number'] ?? '--',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primarySkyBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next['patient_name'] ?? 'Patient',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    next['appointment_time'] ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.campaign_rounded, size: 18),
            label: const Text('CALL PATIENT'),
            onPressed: () async {
              Navigator.pop(ctx);
              final current = appointments.firstWhere(
                (a) =>
                    a['appointment_status'] == 'IN_CONSULTATION' ||
                    a['queue_status'] == 'IN_PROGRESS',
                orElse: () => <String, dynamic>{},
              );
              final currentId = (current['id'] as int?) ?? 0;
              final nextId = (next['id'] as int?) ?? 0;
              await DoctorService.updateAppointmentStatus(
                  nextId, 'IN_CONSULTATION');
              if (currentId > 0) {
                await DoctorService.updateAppointmentStatus(
                    currentId, 'COMPLETED');
              }
              await _fetchStats();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Calling ${next['queue_number']} — ${next['patient_name']}'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Builders
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: value.length > 3 ? 18 : 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientBanner({
    required String label,
    required String queueNum,
    required String name,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '$queueNum — $name',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.mutedText)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 15, color: AppTheme.mutedText),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
