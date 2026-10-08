import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';

/// Consultation screen for the active patient.
/// Receives the appointment [Map] via [ModalRoute.settings.arguments].
class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({super.key});

  @override
  State<DoctorConsultationScreen> createState() =>
      _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen> {
  final _notesController = TextEditingController();
  bool _isSaving = false;
  bool _started = false;

  // DB-fetched values for the Appointment Details card
  String _dbTime = 'Loading...';
  String _dbDate = 'Loading...';
  String _dbNotes = '';

  // DB-fetched values for the Patient Details card
  String _dbBloodGroup = 'Loading...';
  String _dbAllergies = 'Loading...';
  String _dbMedicalConditions = 'Loading...';
  String _dbAddress = 'Loading...';

  bool _isFetchingDb = true;
  bool _isInit = false;

  Map<String, dynamic> get _appt =>
      (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ??
      {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      _fetchFromDB();
    }
  }

  Future<void> _fetchFromDB() async {
    final appt = _appt;
    // Use the real appointment ID passed from the Queue screen.
    // The ID is the primary key of the opd_appointments table row.
    final apptId = (appt['id'] as int?) ?? 0;

    final details = await DoctorService.getConsultationDetails(apptId);

    if (mounted) {
      setState(() {
        _isFetchingDb = false;
        _dbTime = details['time']!;
        _dbDate = details['date']!;
        _dbNotes = details['notes'] == 'Not provided' ? '' : details['notes']!;
        _dbBloodGroup = details['blood_group']!;
        _dbAllergies = details['allergies']!;
        _dbMedicalConditions = details['medical_conditions']!;
        _dbAddress = details['address']!;

        // Pre-fill the editable notes field with DB notes
        if (_dbNotes.isNotEmpty && _notesController.text.isEmpty) {
          _notesController.text = _dbNotes;
        }
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startConsultation() async {
    final id = (_appt['id'] as int?) ?? 0;
    setState(() => _isSaving = true);
    final success =
        await DoctorService.updateAppointmentStatus(id, 'IN_CONSULTATION');
    if (mounted) {
      setState(() {
        _isSaving = false;
        _started = success;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Consultation started.'
                : 'Could not start consultation. Please try again.',
          ),
          backgroundColor:
              success ? AppTheme.doctorPrimaryColor : AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _completeConsultation() async {
    final id = (_appt['id'] as int?) ?? 0;
    setState(() => _isSaving = true);
    final success = await DoctorService.updateAppointmentStatus(
      id,
      'COMPLETED',
      notes: _notesController.text.trim(),
    );
    if (!success) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete consultation. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    // Automatically move 'Next Patient' to 'Currently In Consultation'
    final appointments = await DoctorService.getTodayAppointments();
    var nextPatientCalled = false;
    final waitingList =
        appointments.where(DoctorService.isAppointmentWaiting).toList();
    final hasWaitingPatient = waitingList.isNotEmpty;

    if (hasWaitingPatient) {
      final nextPatientId = (waitingList.first['id'] as int?) ?? 0;
      nextPatientCalled = await DoctorService.updateAppointmentStatus(
        nextPatientId,
        'IN_CONSULTATION',
      );
    }

    if (mounted) setState(() => _isSaving = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextPatientCalled
              ? 'Consultation completed. Next patient called automatically.'
              : hasWaitingPatient
                  ? 'Consultation completed, but the next patient could not be called. Please refresh the queue.'
                  : 'Consultation completed. No next patient was waiting.',
        ),
        backgroundColor: hasWaitingPatient && !nextPatientCalled
            ? AppTheme.errorRed
            : const Color(0xFF10B981),
      ),
    );
    // Pop back to queue
    Navigator.pushReplacementNamed(context, '/doctor-queue');
  }

  @override
  Widget build(BuildContext context) {
    final appt = _appt;
    final appointmentTime = appt['appointment_time']?.toString().trim();
    final appointmentTimeForDetails = appointmentTime?.isNotEmpty == true
        ? appointmentTime!
        : _formatAppointmentTime(_dbTime);
    final isInConsultation =
        _started || DoctorService.isAppointmentInConsultation(appt);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.doctorPrimaryColor),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Stepper ──
            _buildStatusStepper(isInConsultation),
            const SizedBox(height: 20),

            // ── Patient Header Card ──
            Container(
              width: double.infinity,
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${appt['patient_id'] ?? ''} · Age ${appt['patient_age'] ?? '--'}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${appt['appointment_time'] ?? ''} — ${appt['patient_gender'] ?? ''}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Appointment Details ──
            _buildInfoCard(
              title: 'Appointment Details',
              icon: Icons.calendar_today_rounded,
              children: [
                _infoRow(
                  'Time',
                  _isFetchingDb ? 'Loading...' : appointmentTimeForDetails,
                ),
                _infoRow('Date', _isFetchingDb ? 'Loading...' : _dbDate),
                _infoRow(
                    'Notes',
                    _isFetchingDb
                        ? 'Loading...'
                        : (_dbNotes.isEmpty ? 'Not provided' : _dbNotes)),
              ],
            ),

            const SizedBox(height: 16),

            // ── Patient Details (Expandable) ──
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Row(
                    children: [
                      Icon(Icons.person_search_rounded,
                          size: 18, color: AppTheme.doctorPrimaryColor),
                      SizedBox(width: 8),
                      Text('Patient Details',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText)),
                    ],
                  ),
                  childrenPadding:
                      const EdgeInsets.only(left: 18, right: 18, bottom: 18),
                  children: [
                    const Divider(height: 10),
                    const SizedBox(height: 10),
                    _infoRow(
                        'Blood Group', _isFetchingDb ? '...' : _dbBloodGroup),
                    _infoRow('Allergies', _isFetchingDb ? '...' : _dbAllergies),
                    _infoRow('Conditions',
                        _isFetchingDb ? '...' : _dbMedicalConditions),
                    _infoRow('Address', _isFetchingDb ? '...' : _dbAddress),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Consultation Notes ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.note_alt_rounded,
                            size: 18, color: AppTheme.doctorPrimaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Consultation Notes',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText:
                            'Enter diagnosis, treatment plan, prescriptions, follow-up instructions...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Action Buttons ──
            if (!isInConsultation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Consultation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: _isSaving ? null : _startConsultation,
                ),
              ),

            if (isInConsultation)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_rounded),
                  label: const Text('Complete Consultation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: _isSaving ? null : _completeConsultation,
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Status Stepper
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildStatusStepper(bool isInConsultation) {
    final steps = ['Waiting', 'Called', 'In Consultation', 'Completed'];
    final currentStep = isInConsultation ? 2 : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final label = entry.value;
          final isActive = i <= currentStep;
          final isCurrent = i == currentStep;

          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isActive
                          ? AppTheme.doctorPrimaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isCurrent
                                ? AppTheme.doctorPrimaryColor
                                : const Color(0xFF10B981))
                            : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCurrent
                            ? Icons.radio_button_checked_rounded
                            : i < currentStep
                                ? Icons.check_rounded
                                : Icons.circle_outlined,
                        size: 14,
                        color: isActive ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                        color:
                            isActive ? AppTheme.darkText : AppTheme.mutedText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatAppointmentTime(String value) {
    final match = RegExp(
      r'(?:T|\s)(\d{2}):(\d{2})(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?$',
    ).firstMatch(value.trim());
    if (match == null) return value;

    final hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.doctorPrimaryColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.mutedText,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText)),
          ),
        ],
      ),
    );
  }
}
