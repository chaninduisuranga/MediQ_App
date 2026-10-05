import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  static const List<Map<String, dynamic>> _staffOpdRooms = [
    {
      'key': 'GENERAL_OPD',
      'name': 'General OPD',
      'subtitle': 'General Medical OPD Consultation',
      'color': 0xFF0284C7,
    },
    {
      'key': 'DRESSING_ROOM',
      'name': 'Dressing Room',
      'subtitle': 'Wound Care & Bandaging',
      'color': 0xFF0077B6,
    },
    {
      'key': 'INJECTION_ROOM',
      'name': 'Injection Room',
      'subtitle': 'IV & IM Injections',
      'color': 0xFF00A896,
    },
    {
      'key': 'ANIMAL_BITE_ROOM',
      'name': 'Animal Bite Room',
      'subtitle': 'Bite Wounds & ARV Treatment',
      'color': 0xFFD97706,
    },
    {
      'key': 'BLEEDING_ROOM',
      'name': 'Bleeding Room',
      'subtitle': 'Hemorrhage & Bleeding Control',
      'color': 0xFFE11D48,
    },
    {
      'key': 'DISPENSARY_ROOM',
      'name': 'Dispensary',
      'subtitle': 'Medicine collection',
      'color': 0xFF2563EB,
    },
  ];

  String _selectedRoomKey = 'GENERAL_OPD';
  bool _isLoading = true;
  // ignore: prefer_final_fields
  bool _isOnDuty = true;
  int _totalCount = 0;
  int _checkedInCount = 0;
  int _waitingCount = 0;
  int _inProgressCount = 0;
  int _priorityCount = 0;
  String _currentToken = '--';
  int _avgWaitTime = 15;

  @override
  void initState() {
    super.initState();
    _fetchQueueStats();
  }

  Future<void> _fetchQueueStats() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final appointments = await QueueService.getStaffQueue();
      if (!mounted) return;
      final activePatient = appointments.firstWhere(
        (a) => a['status'] == 'IN_PROGRESS',
        orElse: () => <String, dynamic>{},
      );

      setState(() {
        _totalCount = appointments.length;
        _checkedInCount =
            appointments.where((a) => a['status'] == 'CHECKED_IN').length;
        _inProgressCount =
            appointments.where((a) => a['status'] == 'IN_PROGRESS').length;
        _waitingCount = appointments
            .where((a) =>
                a['status'] == 'PENDING' ||
                a['status'] == 'CONFIRMED' ||
                a['status'] == 'CHECKED_IN')
            .length;
        _priorityCount =
            appointments.where((a) => (a['priority'] as bool?) == true).length;
        _currentToken = activePatient.isNotEmpty
            ? (activePatient['queue_number'] ?? '--')
            : '--';
        _avgWaitTime = (_waitingCount > 0) ? (_waitingCount * 5) : 10;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load the Staff queue: $error'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  void _showQuickCallNextDialog() async {
    late final List<Map<String, dynamic>> appointments;
    try {
      appointments = await QueueService.getStaffQueue();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load the Staff queue: $error'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    final waiting = appointments
        .where((a) =>
            a['status'] == 'CHECKED_IN' ||
            a['status'] == 'PENDING' ||
            a['status'] == 'CONFIRMED')
        .toList();
    if (!mounted) return;

    if (waiting.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients currently waiting in this room queue.'),
          backgroundColor: AppTheme.mutedText,
        ),
      );
      return;
    }

    final nextAppt = waiting.first;
    final token = nextAppt['queue_number'] ?? 'N/A';
    final patientName = nextAppt['patient_name'] ?? 'Patient';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded,
                color: AppTheme.primarySkyBlue, size: 28),
            SizedBox(width: 10),
            Text('Call Next Patient',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm calling patient to consultation room:',
                style: TextStyle(fontSize: 13, color: AppTheme.mutedText)),
            const SizedBox(height: 16),
            Container(
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
                    'TOKEN #$token',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primarySkyBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patientName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Room: ${AppointmentService.getRoomDisplayName(_selectedRoomKey)}',
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
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final active = appointments.firstWhere(
                  (a) => a['status'] == 'IN_PROGRESS',
                  orElse: () => <String, dynamic>{});
              final currentId =
                  int.tryParse(active['id']?.toString() ?? '') ?? 0;
              final nextId =
                  int.tryParse(nextAppt['id']?.toString() ?? '') ?? 0;

              try {
                if (currentId > 0) {
                  await QueueService.updateStaffPatientStatus(
                    currentId,
                    'COMPLETED',
                  );
                }
                await QueueService.callStaffPatient(nextId);
                await _fetchQueueStats();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Calling Token #$token ($patientName) to Room!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not call the next patient: $error'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('CALL NOW'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRoomName =
        AppointmentService.getRoomDisplayName(_selectedRoomKey);

    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.staffDashboard),
      appBar: AppBar(
        title: const Text(
          'Staff Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Queue History',
            onPressed: () => Navigator.pushNamed(context, '/queue-history'),
          ),
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
              // Header Banner Card with Staff Info & On Duty status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primarySkyBlue.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.badge_rounded,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chaminda Bandara',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Senior OPD Staff | ID: STF-8842',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isOnDuty
                                ? Colors.lightGreenAccent.shade400
                                    .withValues(alpha: 0.3)
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white30),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _isOnDuty
                                      ? Colors.greenAccent
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isOnDuty ? 'ON DUTY' : 'OFF DUTY',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
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

              const SizedBox(height: 24),

              // Room Selector Section
              const Text(
                'Select OPD / Room Area',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoomKey,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.primarySkyBlue),
                    items: _staffOpdRooms.map((room) {
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkText),
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

              // Doctor Patient Allocation Banner (Specific to General OPD)
              if (_selectedRoomKey == 'GENERAL_OPD') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF10B981).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medical_services_rounded,
                            color: Color(0xFF059669), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor Allocation',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manage patient allocation among available OPD doctors.',
                              style: TextStyle(
                                  fontSize: 11.5, color: AppTheme.mutedText),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.doctorAllocation),
                        child: const Text(
                          'MANAGE',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Overview Cards Section
              Row(
                children: [
                  Text(
                    'Queue Overview ($selectedRoomName)',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const Spacer(),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primarySkyBlue),
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
                    countText: '$_totalCount',
                    icon: Icons.groups_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  _buildStatCard(
                    title: 'Checked-In',
                    countText: '$_checkedInCount',
                    icon: Icons.how_to_reg_rounded,
                    color: AppTheme.primarySkyBlue,
                  ),
                  _buildStatCard(
                    title: 'In Progress',
                    countText: '$_inProgressCount',
                    icon: Icons.sync_rounded,
                    color: Colors.orange.shade700,
                  ),
                  _buildStatCard(
                    title: 'Waiting List',
                    countText: '$_waitingCount',
                    icon: Icons.hourglass_top_rounded,
                    color: AppTheme.mutedText,
                  ),
                  _buildStatCard(
                    title: 'Priority Patients',
                    countText: '$_priorityCount',
                    icon: Icons.assignment_late_rounded,
                    color: AppTheme.errorRed,
                  ),
                  _buildStatCard(
                    title: 'Current Token',
                    countText: _currentToken,
                    icon: Icons.confirmation_number_rounded,
                    color: AppTheme.primarySkyBlue,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Avg Waiting Time Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primarySkyBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: AppTheme.primarySkyBlue, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Average Waiting Time: ',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText),
                    ),
                    Text(
                      '~$_avgWaitTime min per patient',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primarySkyBlue),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Quick Actions Navigation & Tools
              const Text(
                'Quick Navigation & Staff Tools',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText),
              ),
              const SizedBox(height: 14),

              _buildNavigationTile(
                title: 'Live OPD Queue Management',
                subtitle: 'View queue, call next patient, update status',
                icon: Icons.live_tv_rounded,
                color: AppTheme.primarySkyBlue,
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
                title: 'Call Next Patient',
                subtitle: 'Direct turn call popup for selected room',
                icon: Icons.campaign_rounded,
                color: Colors.orange.shade800,
                onTap: _showQuickCallNextDialog,
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

              const SizedBox(height: 12),

              _buildNavigationTile(
                title: 'Queue History',
                subtitle: 'View past called, skipped & completed records',
                icon: Icons.history_rounded,
                color: Colors.purple.shade600,
                onTap: () {
                  Navigator.pushNamed(context, '/queue-history');
                },
              ),

              const SizedBox(height: 12),

              _buildNavigationTile(
                title: 'Staff Profile & Shift Details',
                subtitle: 'Manage duty status, shift & account info',
                icon: Icons.person_pin_rounded,
                color: AppTheme.mutedText,
                onTap: () {
                  Navigator.pushNamed(context, '/staff-profile');
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String countText,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            countText,
            style: TextStyle(
              fontSize: countText.length > 3 ? 20 : 26,
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
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: AppTheme.mutedText),
          ],
        ),
      ),
    );
  }
}
