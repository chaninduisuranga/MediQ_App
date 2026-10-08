import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class OpdQueueScreen extends StatefulWidget {
  final String? initialRoomKey;

  const OpdQueueScreen({super.key, this.initialRoomKey});

  @override
  State<OpdQueueScreen> createState() => _OpdQueueScreenState();
}

class _OpdQueueScreenState extends State<OpdQueueScreen>
    with SingleTickerProviderStateMixin {
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

  late String _selectedRoomKey;
  late TabController _tabController;
  bool _isCallingNext = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomKey =
        widget.initialRoomKey ?? QueueService.selectedStaffRoomKey;
    QueueService.setSelectedStaffRoomKey(_selectedRoomKey);
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('roomKey')) {
      final key = args['roomKey'] as String;
      if (key != _selectedRoomKey) {
        setState(() {
          _selectedRoomKey = key;
        });
        QueueService.setSelectedStaffRoomKey(key);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCallNext(List<Map<String, dynamic>> queue) async {
    if (_isCallingNext) return;

    final currentAppt = queue.firstWhere(
      (a) => a['status'] == 'IN_PROGRESS',
      orElse: () => <String, dynamic>{},
    );

    final waitingList = queue
        .where((a) =>
            a['status'] == 'CHECKED_IN' ||
            a['status'] == 'PENDING' ||
            a['status'] == 'CONFIRMED')
        .toList();

    if (waitingList.isEmpty && currentAppt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients currently waiting in queue to call.'),
          backgroundColor: AppTheme.mutedText,
        ),
      );
      return;
    }

    final nextAppt =
        waitingList.isNotEmpty ? waitingList.first : <String, dynamic>{};
    final currentId = int.tryParse(currentAppt['id']?.toString() ?? '') ?? 0;
    final nextId = int.tryParse(nextAppt['id']?.toString() ?? '') ?? 0;

    if (nextId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more waiting patients in queue.'),
          backgroundColor: AppTheme.mutedText,
        ),
      );
      return;
    }

    final token = (nextAppt['queue_number'] ?? 'N/A').toString();
    final patientName = nextAppt['patient_name'] ?? 'Patient';
    final roomDisplayName =
        AppointmentService.getRoomDisplayName(_selectedRoomKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Now Calling',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Column(
                children: [
                  Text(
                    '$token',
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.orange.shade800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    patientName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    roomDisplayName,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.mutedText,
                        fontWeight: FontWeight.w600),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              if (mounted) setState(() => _isCallingNext = true);
              if (mounted) {
                try {
                  if (currentId > 0) {
                    await QueueService.updateStaffPatientStatus(
                      currentId,
                      'COMPLETED',
                      roomKey: _selectedRoomKey,
                    );
                  }
                  await QueueService.callStaffPatient(
                    nextId,
                    roomKey: _selectedRoomKey,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Calling Token #$token ($patientName) to Room!'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Could not call the next patient: $error'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isCallingNext = false);
                }
              }
            },
            child: const Text('OK - CALL PATIENT'),
          ),
        ],
      ),
    );
  }

  void _showSkipDialog(int patientId, String token, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.redo_rounded, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Skip Patient #$token',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skip turn for $name?',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await QueueService.updateStaffPatientStatus(
                  patientId,
                  'SKIPPED',
                  roomKey: _selectedRoomKey,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Patient #$token marked as Skipped.'),
                      backgroundColor: Colors.grey.shade700,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Could not skip patient: $error'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('CONFIRM SKIP'),
          ),
        ],
      ),
    );
  }

  void _showRecallDialog(int patientId, String token, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.replay_rounded, color: AppTheme.primarySkyBlue),
            SizedBox(width: 10),
            Text('Recall Patient',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Recall patient #$token ($name) back into the active waiting queue?',
          style: const TextStyle(fontSize: 14, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await QueueService.updateStaffPatientStatus(
                  patientId,
                  'RECALL',
                  roomKey: _selectedRoomKey,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content:
                          Text('Patient #$token recalled to waiting list.'),
                      backgroundColor: AppTheme.primarySkyBlue,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Could not recall patient: $error'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('RECALL PATIENT'),
          ),
        ],
      ),
    );
  }

  void _showNoShowDialog(int patientId, String token, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_off_rounded, color: AppTheme.errorRed),
            SizedBox(width: 10),
            Text('Mark No Show',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Mark patient #$token ($name) as not present?',
          style: const TextStyle(fontSize: 14, color: AppTheme.darkText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await QueueService.updateStaffPatientStatus(
                  patientId,
                  'NO_SHOW',
                  roomKey: _selectedRoomKey,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Patient #$token marked as No Show.'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content:
                          Text('Could not mark patient as No Show: $error'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: const Text('CONFIRM NO SHOW'),
          ),
        ],
      ),
    );
  }

  void _showPriorityDialog(
      int patientId, String token, String name, bool currentPriority) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.priority_high_rounded, color: AppTheme.errorRed),
            const SizedBox(width: 10),
            Text(currentPriority ? 'Update Priority' : 'Mark as Priority',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${currentPriority ? 'Remove priority from' : 'Mark'} $name (#$token)?',
              style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await QueueService.markStaffPatientPriority(
                  patientId,
                  isPriority: !currentPriority,
                  roomKey: _selectedRoomKey,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        currentPriority
                            ? 'Priority removed for patient #$token.'
                            : 'Patient #$token marked as Priority.',
                      ),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Could not update priority: $error'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            child: Text(currentPriority ? 'REMOVE PRIORITY' : 'SET PRIORITY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomDisplayName =
        AppointmentService.getRoomDisplayName(_selectedRoomKey);
    final roomColor = Color(AppointmentService.getRoomColor(_selectedRoomKey));

    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.opdQueue),
      appBar: AppBar(
        title: Text(
          '$roomDisplayName Queue',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_selectedRoomKey == 'GENERAL_OPD')
            IconButton(
              icon: const Icon(Icons.medical_services_rounded,
                  color: Color(0xFF059669)),
              tooltip: 'Doctor Allocation',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.doctorAllocation,
                arguments: {'roomKey': _selectedRoomKey},
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primarySkyBlue,
          labelColor: AppTheme.primarySkyBlue,
          unselectedLabelColor: AppTheme.mutedText,
          tabs: const [
            Tab(
                icon: Icon(Icons.format_list_numbered_rounded),
                text: 'Active Queue'),
            Tab(
                icon: Icon(Icons.history_toggle_off_rounded),
                text: 'Skipped & Completed'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: QueueService.getStaffQueueStream(roomKey: _selectedRoomKey),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load the Staff queue: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.errorRed),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final queueData = snapshot.data ?? [];

          // Stats calculation
          final currentPatient = queueData.firstWhere(
            (a) => a['status'] == 'IN_PROGRESS',
            orElse: () => <String, dynamic>{},
          );

          final waitingList = queueData
              .where((a) =>
                  a['status'] == 'CHECKED_IN' ||
                  a['status'] == 'PENDING' ||
                  a['status'] == 'CONFIRMED')
              .toList();

          final skippedOrCompletedList = queueData
              .where((a) =>
                  a['status'] == 'SKIPPED' ||
                  a['status'] == 'COMPLETED' ||
                  a['status'] == 'NO_SHOW')
              .toList();

          final currentToken = currentPatient.isNotEmpty
              ? (currentPatient['queue_number'] ?? '--').toString()
              : '--';
          final avgWaitTime =
              waitingList.isNotEmpty ? (waitingList.length * 5) : 10;

          return TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Active Queue View
              Column(
                children: [
                  // Room Switcher Bar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Text('Room: ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.lightBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedRoomKey,
                                isExpanded: true,
                                items: _staffOpdRooms.map((r) {
                                  return DropdownMenuItem<String>(
                                    value: r['key'] as String,
                                    child: Text(
                                      r['name'] as String,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedRoomKey = val;
                                    });
                                    QueueService.setSelectedStaffRoomKey(val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Doctor Allocation Quick-Action Card for General OPD
                  if (_selectedRoomKey == 'GENERAL_OPD')
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppTheme.primarySkyBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_rounded,
                              color: AppTheme.primarySkyBlue, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Doctor Allocation',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppTheme.primarySkyBlue,
                            ),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.doctorAllocation,
                              arguments: {'roomKey': _selectedRoomKey},
                            ),
                            child: const Text('Manage &rarr;',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // Room Stats Summary Strip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: AppTheme.lightBg,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMiniStat(
                            'Token', '$currentToken', AppTheme.primarySkyBlue),
                        _buildMiniStat('Waiting', '${waitingList.length}',
                            AppTheme.primaryBlue),
                        _buildMiniStat(
                            'In Progress',
                            currentPatient.isNotEmpty ? '1' : '0',
                            Colors.orange.shade800),
                        _buildMiniStat(
                            'Avg Wait', '~${avgWaitTime}m', AppTheme.mutedText),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Prominent Currently Serving Card
                          _buildCurrentPatientCard(currentPatient, roomColor),

                          const SizedBox(height: 16),

                          // CALL NEXT PATIENT Action Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isCallingNext
                                  ? null
                                  : () => _handleCallNext(queueData),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primarySkyBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              icon: _isCallingNext
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5),
                                    )
                                  : const Icon(Icons.campaign_rounded,
                                      size: 26),
                              label: Text(
                                _isCallingNext
                                    ? 'CALLING PATIENT...'
                                    : 'CALL NEXT PATIENT',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Waiting Queue Header
                          Row(
                            children: [
                              const Text(
                                'Waiting Queue List',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkText),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primarySkyBlue
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${waitingList.length}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primarySkyBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          if (waitingList.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 44, color: AppTheme.accentGreen),
                                  SizedBox(height: 10),
                                  Text(
                                    'No Patients Waiting',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.darkText),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'The queue is currently clear for this room.',
                                    style: TextStyle(
                                        color: AppTheme.mutedText,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: waitingList.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = waitingList[index];
                                final id = int.tryParse(
                                        item['id']?.toString() ?? '') ??
                                    0;
                                final token =
                                    (item['queue_number'] ?? '${index + 1}')
                                        .toString();
                                final name = item['patient_name'] ?? 'Patient';
                                final status =
                                    item['status'] as String? ?? 'PENDING';
                                final isPriority =
                                    (item['priority'] as bool?) ?? false;
                                final priorityCat =
                                    item['priority_category'] as String?;
                                final isCheckedIn = status == 'CHECKED_IN';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isPriority
                                          ? AppTheme.errorRed
                                              .withValues(alpha: 0.5)
                                          : (isCheckedIn
                                              ? AppTheme.accentGreen
                                                  .withValues(alpha: 0.4)
                                              : Colors.grey.shade200),
                                      width:
                                          (isPriority || isCheckedIn) ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isPriority
                                                  ? AppTheme.errorRed
                                                      .withValues(alpha: 0.15)
                                                  : (isCheckedIn
                                                      ? AppTheme.accentGreen
                                                          .withValues(
                                                              alpha: 0.15)
                                                      : AppTheme.lightBg),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$token',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isPriority
                                                    ? AppTheme.errorRed
                                                    : (isCheckedIn
                                                        ? AppTheme.accentGreen
                                                        : AppTheme.darkText),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: AppTheme.darkText,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Pos: #${index + 1} | NIC: ${item['patient_nic'] ?? 'N/A'}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppTheme.mutedText),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isPriority)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.errorRed,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'PRIORITY${priorityCat != null ? ' ($priorityCat)' : ''}',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isCheckedIn
                                                    ? AppTheme.accentGreen
                                                        .withValues(alpha: 0.15)
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isCheckedIn
                                                    ? 'Checked-In'
                                                    : 'Waiting',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCheckedIn
                                                      ? AppTheme.accentGreen
                                                      : AppTheme.mutedText,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),

                                      // Action Buttons Row (Priority, Skip, Call)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 32),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              side: BorderSide(
                                                  color: isPriority
                                                      ? AppTheme.errorRed
                                                      : AppTheme.mutedText),
                                            ),
                                            onPressed: () =>
                                                _showPriorityDialog(id, token,
                                                    name, isPriority),
                                            icon: Icon(
                                              Icons.priority_high_rounded,
                                              size: 14,
                                              color: isPriority
                                                  ? AppTheme.errorRed
                                                  : AppTheme.mutedText,
                                            ),
                                            label: Text(
                                              isPriority
                                                  ? 'Priority'
                                                  : 'Set Priority',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isPriority
                                                    ? AppTheme.errorRed
                                                    : AppTheme.mutedText,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 32),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              side: BorderSide(
                                                  color: Colors.grey.shade400),
                                            ),
                                            onPressed: () => _showSkipDialog(
                                                id, token, name),
                                            icon: const Icon(Icons.redo_rounded,
                                                size: 14,
                                                color: AppTheme.mutedText),
                                            label: const Text('Skip',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme.mutedText)),
                                          ),
                                          PopupMenuButton<String>(
                                            tooltip: 'More queue actions',
                                            onSelected: (action) {
                                              if (action == 'NO_SHOW') {
                                                _showNoShowDialog(
                                                    id, token, name);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem<String>(
                                                value: 'NO_SHOW',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.person_off_rounded,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('No Show'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // TAB 2: Skipped & Completed Queue History View
              ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: skippedOrCompletedList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = skippedOrCompletedList[index];
                  final id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
                  final token = (item['queue_number'] ?? 'N/A').toString();
                  final name = item['patient_name'] ?? 'Patient';
                  final status = item['status'] as String? ?? 'COMPLETED';
                  final isSkipped = status == 'SKIPPED';

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSkipped
                                ? Colors.grey.shade200
                                : AppTheme.accentGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$token',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isSkipped
                                  ? Colors.grey.shade700
                                  : AppTheme.accentGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.darkText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSkipped
                                    ? 'Reason: ${item['skip_reason'] ?? 'Not Present'}'
                                    : 'Status: Completed',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isSkipped
                                        ? Colors.grey.shade700
                                        : AppTheme.accentGreen),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            backgroundColor: AppTheme.primarySkyBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () => _showRecallDialog(id, token, name),
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Recall',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.mutedText)),
      ],
    );
  }

  Widget _buildCurrentPatientCard(
      Map<String, dynamic> patient, Color roomColor) {
    final hasPatient = patient.isNotEmpty;
    final token = hasPatient
        ? (patient['queue_number'] ?? 'N/A').toString()
        : '--';
    final name = hasPatient
        ? (patient['patient_name'] ?? 'Unknown')
        : 'No Active Patient';
    final nic = hasPatient ? (patient['patient_nic'] ?? 'N/A') : 'N/A';
    final phone = hasPatient ? (patient['patient_phone'] ?? 'N/A') : 'N/A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roomColor, AppTheme.primarySkyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: roomColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CURRENTLY SERVING',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              ),
              const Icon(Icons.medical_services_rounded,
                  color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '$token',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIC: $nic',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      'Phone: $phone',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
