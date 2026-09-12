import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  String _selectedRoomKey = 'DRESSING_ROOM';
  bool _isLoading = true;
  int _totalCount = 0;
  int _checkedInCount = 0;
  int _waitingCount = 0;
  int _inProgressCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchQueueStats();
  }

  Future<void> _fetchQueueStats() async {
    setState(() => _isLoading = true);
    final appointments = await QueueService.getQueueByRoom(_selectedRoomKey);
    if (mounted) {
      setState(() {
        _totalCount = appointments.length;
        _checkedInCount = appointments.where((a) => a['status'] == 'CHECKED_IN').length;
        _inProgressCount = appointments.where((a) => a['status'] == 'IN_PROGRESS').length;
        _waitingCount = appointments.where((a) => a['status'] == 'PENDING' || a['status'] == 'CONFIRMED').length;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoomName = AppointmentService.getRoomDisplayName(_selectedRoomKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Staff Management Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: _fetchQueueStats,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchQueueStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OPD Staff Control Center',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Real-time queue monitoring & check-in',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Room Selector Section
              const Text(
                'Select OPD Room',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoomKey,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primaryTeal),
                    items: AppointmentService.opdRooms.map((room) {
                      return DropdownMenuItem<String>(
                        value: room['key'] as String,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(room['color'] as int),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              room['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.darkText),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRoomKey = val;
                        });
                        _fetchQueueStats();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Overview Cards Section
              Row(
                children: [
                  Text(
                    'Queue Overview ($selectedRoomName)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTeal),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Overview Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard(
                    title: 'Total Patients',
                    count: _totalCount,
                    icon: Icons.groups_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  _buildStatCard(
                    title: 'Checked-In',
                    count: _checkedInCount,
                    icon: Icons.how_to_reg_rounded,
                    color: AppTheme.accentGreen,
                  ),
                  _buildStatCard(
                    title: 'In Progress',
                    count: _inProgressCount,
                    icon: Icons.sync_rounded,
                    color: Colors.orange.shade700,
                  ),
                  _buildStatCard(
                    title: 'Waiting List',
                    count: _waitingCount,
                    icon: Icons.hourglass_top_rounded,
                    color: AppTheme.mutedText,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Quick Actions Navigation Buttons
              const Text(
                'Quick Navigation & Staff Tools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 14),

              _buildNavigationTile(
                title: 'Live OPD Queue Management',
                subtitle: 'View queue, call next patient, update status',
                icon: Icons.live_tv_rounded,
                color: AppTheme.primaryTeal,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/opd-queue',
                    arguments: {'roomKey': _selectedRoomKey},
                  );
                },
              ),

              const SizedBox(height: 12),

              _buildNavigationTile(
                title: 'QR Code Scanner',
                subtitle: 'Scan patient ticket QR or enter ID manually',
                icon: Icons.qr_code_scanner_rounded,
                color: AppTheme.primaryBlue,
                onTap: () {
                  Navigator.pushNamed(context, '/qr-scanner');
                },
              ),

              const SizedBox(height: 12),

              _buildNavigationTile(
                title: 'Patient Check-In Counter',
                subtitle: 'Verify patient details and confirm check-in',
                icon: Icons.check_circle_outline_rounded,
                color: AppTheme.accentGreen,
                onTap: () {
                  Navigator.pushNamed(context, '/check-in');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
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
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.mutedText),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
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
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.mutedText),
          ],
        ),
      ),
    );
  }
}
