import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../widgets/doctor_bottom_nav_bar.dart';

class DoctorQueueScreen extends StatefulWidget {
  const DoctorQueueScreen({super.key});

  @override
  State<DoctorQueueScreen> createState() => _DoctorQueueScreenState();
}

class _DoctorQueueScreenState extends State<DoctorQueueScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchQueue();
  }

  Future<void> _fetchQueue() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final list = await DoctorService.getTodayAppointments();
    if (mounted) {
      setState(() {
        _appointments = list;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> get _currentPatient {
    if (_appointments.isNotEmpty &&
        QueueService.isQueueEntryActive(_appointments.first)) {
      return _appointments.first;
    }
    return _appointments.firstWhere(
      (appointment) =>
          QueueService.isQueueEntryActive(appointment) ||
          DoctorService.isAppointmentInConsultation(appointment),
      orElse: () => <String, dynamic>{},
    );
  }

  List<Map<String, dynamic>> get _waitingList =>
      _appointments.where(DoctorService.isAppointmentWaiting).toList();

  @override
  Widget build(BuildContext context) {
    final current = _currentPatient;
    final waiting = _waitingList;
    final next = waiting.isNotEmpty ? waiting.first : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchQueue,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppTheme.doctorPrimaryColor))
          : RefreshIndicator(
              onRefresh: _fetchQueue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Current Patient Panel ──
                    _buildSectionTitle(
                        'Currently In Consultation',
                        Icons.medical_services_rounded,
                        AppTheme.doctorPrimaryColor),
                    const SizedBox(height: 10),
                    current.isNotEmpty
                        ? _buildCurrentPatientCard(current)
                        : _buildEmptyPanel('No patient in consultation',
                            Icons.person_off_rounded, AppTheme.mutedText),
                    const SizedBox(height: 20),

                    // ── Next Patient Panel ──
                    _buildSectionTitle(
                        'Next Patient',
                        Icons.arrow_circle_right_rounded,
                        const Color(0xFF0D9488)),
                    const SizedBox(height: 10),
                    next.isNotEmpty
                        ? _buildNextPatientCard(next)
                        : _buildEmptyPanel(
                            'No patient waiting',
                            Icons.event_available_rounded,
                            const Color(0xFF10B981)),
                    const SizedBox(height: 20),

                    // ── Waiting List ──
                    Row(
                      children: [
                        _buildSectionTitle(
                            'Waiting Queue',
                            Icons.format_list_numbered_rounded,
                            const Color(0xFFF59E0B)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${waiting.length} waiting',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF59E0B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    waiting.isEmpty
                        ? _buildEmptyPanel(
                            'Queue is empty — all patients served!',
                            Icons.check_circle_rounded,
                            const Color(0xFF10B981))
                        : Column(
                            children: waiting.asMap().entries.map((entry) {
                              return _buildWaitingCard(
                                  entry.value, entry.key + 1);
                            }).toList(),
                          ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const DoctorBottomNavBar(currentIndex: 2),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Current Patient Card
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCurrentPatientCard(Map<String, dynamic> appt) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.doctorAppBarGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.doctorPrimaryColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  appt['queue_number'] ?? '--',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appt['patient_name'] ?? 'Patient',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${appt['patient_id'] ?? ''} · ${appt['appointment_time'] ?? ''}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Age ${appt['patient_age'] ?? '--'} · ${appt['patient_gender'] ?? ''}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQueueActionButton(
                label: 'Start Consultation',
                icon: Icons.medical_services_rounded,
                color: const Color(0xFF10B981),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/doctor-consultation',
                  arguments: appt,
                ).then((_) => _fetchQueue()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQueueActionButton(
                label: 'Skip Patient',
                icon: Icons.skip_next_rounded,
                color: const Color(0xFFF59E0B),
                onTap: () => _confirmSkip(appt),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Next Patient Card
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildNextPatientCard(Map<String, dynamic> appt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appt['queue_number'] ?? '--',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0D9488)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt['patient_name'] ?? 'Patient',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  appt['appointment_time'] ?? '--',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppTheme.mutedText),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────

  Widget _buildQueueActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: disabled
                  ? Colors.grey.shade300
                  : color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18, color: disabled ? Colors.grey.shade400 : color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: disabled ? Colors.grey.shade400 : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Waiting List Card
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildWaitingCard(Map<String, dynamic> appt, int position) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Position number
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                '$position',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt['patient_name'] ?? 'Patient',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      appt['queue_number'] ?? '--',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.doctorPrimaryColor),
                    ),
                    const Text(' · ',
                        style: TextStyle(color: AppTheme.mutedText)),
                    Text(
                      appt['appointment_time'] ?? '--',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.mutedText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/doctor-patient-detail',
                arguments: appt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.doctorPrimaryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Dialogs & Actions
  // ─────────────────────────────────────────────────────────────────────
  void _confirmSkip(Map<String, dynamic> appt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Skip Patient',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Skip ${appt['patient_name']} (${appt['queue_number']})? They will return to the waiting queue.',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              Navigator.pop(ctx);
              final currentId = (appt['id'] as int?) ?? 0;

              final appointments = await DoctorService.getTodayAppointments();
              final waitingList = appointments
                  .where(DoctorService.isAppointmentWaiting)
                  .where((a) => a['id'] != currentId)
                  .toList();

              final currentRequeued =
                  await DoctorService.updateAppointmentStatus(
                      currentId, 'WAITING');
              if (!currentRequeued) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not return patient to the queue.'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
                return;
              }

              var nextPatientCalled = false;
              if (waitingList.isNotEmpty) {
                final nextPatientId = (waitingList.first['id'] as int?) ?? 0;
                nextPatientCalled = await DoctorService.updateAppointmentStatus(
                  nextPatientId,
                  'IN_CONSULTATION',
                );
              }

              if (!nextPatientCalled && waitingList.isNotEmpty) {
                final restored = await DoctorService.updateAppointmentStatus(
                  currentId,
                  'IN_CONSULTATION',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        restored
                            ? 'Could not call the next patient. The current patient remains in consultation.'
                            : 'Could not call the next patient or restore the current consultation. Refresh the queue.',
                      ),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
                await _fetchQueue();
                return;
              }

              await _fetchQueue();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      nextPatientCalled
                          ? '${waitingList.first['patient_name']} is now in consultation. ${appt['patient_name']} returned to the waiting queue.'
                          : '${appt['patient_name']} returned to the waiting queue. No other patient was waiting.',
                    ),
                    backgroundColor: const Color(0xFFF59E0B),
                  ),
                );
              }
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildEmptyPanel(String message, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
