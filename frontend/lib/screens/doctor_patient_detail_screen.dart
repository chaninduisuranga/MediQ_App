import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';

/// Doctor-specific Patient Detail screen.
/// Receives the appointment [Map] via [ModalRoute.settings.arguments].
class DoctorPatientDetailScreen extends StatelessWidget {
  const DoctorPatientDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appt =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?)
            ?? {};

    final status = (appt['appointment_status'] ?? 'SCHEDULED').toString();
    final statusColor = DoctorService.getStatusColor(status);
    final statusLabel = DoctorService.getStatusLabel(status);

    final canStart = status == 'WAITING' ||
        (appt['queue_status'] ?? '').toString() == 'CHECKED_IN';
    final canContinue = status == 'IN_CONSULTATION' ||
        (appt['queue_status'] ?? '').toString() == 'IN_PROGRESS';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Patient Info Card ──
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.doctorPrimaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 34, color: AppTheme.doctorPrimaryColor),
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
                                  color: AppTheme.darkText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              appt['patient_id'] ?? '--',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.mutedText),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow(Icons.person_outline_rounded, 'Age',
                      '${appt['patient_age'] ?? '--'} years'),
                  _infoRow(Icons.wc_rounded, 'Gender',
                      appt['patient_gender'] ?? '--'),
                  _infoRow(Icons.phone_rounded, 'Phone',
                      appt['patient_phone'] ?? '--'),
                  _infoRow(Icons.water_drop_rounded, 'Blood Group',
                      appt['blood_group'] ?? '--'),
                  _infoRow(Icons.warning_amber_rounded, 'Allergies',
                      appt['allergies'] ?? 'None'),
                  _infoRow(Icons.medical_information_rounded,
                      'Medical Conditions',
                      appt['medical_conditions'] ?? 'None'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Appointment Info Card ──
            _buildCard(
              title: 'Appointment Information',
              titleIcon: Icons.calendar_today_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.confirmation_number_rounded, 'Queue Number',
                      appt['queue_number'] ?? '--'),
                  _infoRow(Icons.schedule_rounded, 'Appointment Time',
                      appt['appointment_time'] ?? '--'),
                  _infoRow(Icons.today_rounded, 'Appointment Date',
                      appt['appointment_date'] ?? '--'),
                  _infoRow(Icons.meeting_room_rounded, 'OPD Room',
                      _roomName(appt['room'] ?? '')),
                  if ((appt['notes'] ?? '').toString().isNotEmpty)
                    _infoRow(Icons.note_alt_rounded, 'Notes',
                        appt['notes'] ?? ''),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Previous Consultations (mock) ──
            _buildCard(
              title: 'Previous Consultations',
              titleIcon: Icons.history_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreviousConsultationItem(
                    date: '2026-09-07',
                    notes: 'Follow-up for hypertension. BP: 140/90. Medication adjusted.',
                    status: 'COMPLETED',
                  ),
                  const Divider(height: 20),
                  _buildPreviousConsultationItem(
                    date: '2026-08-20',
                    notes: 'Routine checkup. All vitals normal. No issues reported.',
                    status: 'COMPLETED',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Action Buttons ──
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (canStart)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.medical_services_rounded),
                      label: const Text('Start Consultation'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981)),
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/doctor-consultation',
                          arguments: appt,
                        );
                      },
                    ),
                  ),
                if (canContinue)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.play_circle_rounded),
                      label: const Text('Continue Consultation'),
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/doctor-consultation',
                          arguments: appt,
                        );
                      },
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Queue'),
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/doctor-queue'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: const Text('Back to Appointments'),
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, '/doctor-appointments'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Builders
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildCard({
    Widget? child,
    String? title,
    IconData? titleIcon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (titleIcon != null)
                  Icon(titleIcon,
                      size: 18, color: AppTheme.doctorPrimaryColor),
                if (titleIcon != null) const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText),
                ),
              ],
            ),
            const Divider(height: 20),
          ],
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.doctorPrimaryColor),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
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

  Widget _buildPreviousConsultationItem({
    required String date,
    required String notes,
    required String status,
  }) {
    final color = DoctorService.getStatusColor(status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.mutedText)),
              const SizedBox(height: 3),
              Text(notes,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.darkText)),
            ],
          ),
        ),
      ],
    );
  }

  String _roomName(String key) {
    const names = {
      'GENERAL_OPD': 'General OPD',
      'DRESSING_ROOM': 'Dressing Room',
      'INJECTION_ROOM': 'Injection Room',
      'ANIMAL_BITE_ROOM': 'Animal Bite Room',
      'BLEEDING_ROOM': 'Bleeding Room',
      'PHARMACY': 'Pharmacy',
      'OPD_CLINIC_ROOM': 'OPD Clinic Room',
    };
    return names[key] ?? key;
  }
}
