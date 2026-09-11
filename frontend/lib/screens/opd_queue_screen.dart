import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';

class OpdQueueScreen extends StatefulWidget {
  final String? initialRoomKey;

  const OpdQueueScreen({super.key, this.initialRoomKey});

  @override
  State<OpdQueueScreen> createState() => _OpdQueueScreenState();
}

class _OpdQueueScreenState extends State<OpdQueueScreen> {
  late String _selectedRoomKey;
  bool _isCallingNext = false;

  @override
  void initState() {
    super.initState();
    _selectedRoomKey = widget.initialRoomKey ?? 'DRESSING_ROOM';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && args.containsKey('roomKey')) {
      setState(() {
        _selectedRoomKey = args['roomKey'] as String;
      });
    }
  }

  Future<void> _handleCallNext(List<Map<String, dynamic>> queue) async {
    if (_isCallingNext) return;

    // Current patient in consultation (IN_PROGRESS)
    final currentAppt = queue.firstWhere(
      (a) => a['status'] == 'IN_PROGRESS',
      orElse: () => <String, dynamic>{},
    );

    // Next candidate to call (prefers CHECKED_IN, then PENDING / CONFIRMED)
    final checkedInCandidates = queue.where((a) => a['status'] == 'CHECKED_IN').toList();
    final pendingCandidates = queue.where((a) => a['status'] == 'PENDING' || a['status'] == 'CONFIRMED').toList();

    final nextAppt = checkedInCandidates.isNotEmpty
        ? checkedInCandidates.first
        : (pendingCandidates.isNotEmpty ? pendingCandidates.first : <String, dynamic>{});

    final currentId = (currentAppt['id'] as int?) ?? 0;
    final nextId = (nextAppt['id'] as int?) ?? 0;

    if (nextId == 0 && currentId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No patients waiting in queue to call.'),
          backgroundColor: AppTheme.mutedText,
        ),
      );
      return;
    }

    setState(() => _isCallingNext = true);
    final success = await QueueService.callNextPatient(currentId, nextId);
    if (mounted) {
      setState(() => _isCallingNext = false);
      if (success) {
        final nextToken = nextAppt['queue_number'] ?? 'N/A';
        final patientName = nextAppt['patient_name'] ?? 'Patient';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling Token #$nextToken ($patientName) to Room!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to call next patient. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomDisplayName = AppointmentService.getRoomDisplayName(_selectedRoomKey);
    final roomColor = Color(AppointmentService.getRoomColor(_selectedRoomKey));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$roomDisplayName Queue',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: QueueService.getQueueStream(_selectedRoomKey),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
          }

          final queueData = snapshot.data ?? [];

          // Current patient IN_PROGRESS
          final currentPatient = queueData.firstWhere(
            (a) => a['status'] == 'IN_PROGRESS',
            orElse: () => <String, dynamic>{},
          );

          // Waiting list (CHECKED_IN, PENDING, CONFIRMED)
          final waitingList = queueData
              .where((a) => a['status'] == 'CHECKED_IN' || a['status'] == 'PENDING' || a['status'] == 'CONFIRMED')
              .toList();

          return Column(
            children: [
              // Room Selector Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Text('Room: ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkText)),
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
                            items: AppointmentService.opdRooms.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['key'] as String,
                                child: Text(
                                  r['name'] as String,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRoomKey = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent Current Patient Card
                      _buildCurrentPatientCard(currentPatient, roomColor),

                      const SizedBox(height: 20),

                      // CALL NEXT Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isCallingNext ? null : () => _handleCallNext(queueData),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                          ),
                          icon: _isCallingNext
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Icon(Icons.campaign_rounded, size: 28),
                          label: Text(
                            _isCallingNext ? 'CALLING PATIENT...' : 'CALL NEXT PATIENT',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Waiting List Section
                      Row(
                        children: [
                          const Text(
                            'Waiting List',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${waitingList.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (waitingList.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 48, color: AppTheme.accentGreen),
                              SizedBox(height: 12),
                              Text(
                                'No Patients Waiting',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'The queue is currently clear for this room.',
                                style: TextStyle(color: AppTheme.mutedText, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: waitingList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = waitingList[index];
                            final status = item['status'] as String? ?? 'PENDING';
                            final isCheckedIn = status == 'CHECKED_IN';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isCheckedIn ? AppTheme.accentGreen.withValues(alpha: 0.4) : Colors.grey.shade200,
                                  width: isCheckedIn ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isCheckedIn
                                          ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                          : AppTheme.lightBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '#${item['queue_number'] ?? index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isCheckedIn ? AppTheme.accentGreen : AppTheme.darkText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['patient_name'] ?? 'Patient',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.darkText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'NIC: ${item['patient_nic'] ?? 'N/A'} | Phone: ${item['patient_phone'] ?? 'N/A'}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCheckedIn
                                          ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isCheckedIn ? 'CHECKED-IN' : 'WAITING',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCheckedIn ? AppTheme.accentGreen : AppTheme.mutedText,
                                      ),
                                    ),
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
          );
        },
      ),
    );
  }

  Widget _buildCurrentPatientCard(Map<String, dynamic> patient, Color roomColor) {
    final hasPatient = patient.isNotEmpty;
    final token = hasPatient ? (patient['queue_number'] ?? 'N/A') : '--';
    final name = hasPatient ? (patient['patient_name'] ?? 'Unknown') : 'No Active Patient';
    final nic = hasPatient ? (patient['patient_nic'] ?? 'N/A') : 'N/A';
    final phone = hasPatient ? (patient['patient_phone'] ?? 'N/A') : 'N/A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roomColor, AppTheme.primaryBlue],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CURRENTLY SERVING',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
              const Icon(Icons.medical_services_rounded, color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '#$token',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIC: $nic',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      'Phone: $phone',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
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
