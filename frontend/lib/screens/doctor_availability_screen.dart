import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';
import '../widgets/doctor_bottom_nav_bar.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  State<DoctorAvailabilityScreen> createState() =>
      _DoctorAvailabilityScreenState();
}

class _DoctorAvailabilityScreenState
    extends State<DoctorAvailabilityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _availability = {};

  static const _allDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
    'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final data = await DoctorService.getAvailability();
    if (mounted) setState(() { _availability = data; _isLoading = false; });
  }

  Future<void> _saveAvailability() async {
    setState(() => _isSaving = true);
    final isAvailable = (_availability['is_available'] as bool?) ?? true;
    await DoctorService.updateAvailability(isAvailable);
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability updated successfully.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  List<String> get _workingDays {
    final raw = _availability['working_days'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  void _toggleDay(String day) {
    final days = List<String>.from(_workingDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    setState(() => _availability['working_days'] = days);
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = (_availability['is_available'] as bool?) ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetch,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.doctorPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Availability Toggle Card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: isAvailable
                          ? AppTheme.doctorAppBarGradient
                          : const LinearGradient(
                              colors: [Color(0xFF64748B), Color(0xFF94A3B8)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (isAvailable
                                  ? AppTheme.doctorPrimaryColor
                                  : Colors.grey)
                              .withValues(alpha: 0.3),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAvailable
                                ? Icons.event_available_rounded
                                : Icons.event_busy_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAvailable ? 'AVAILABLE' : 'UNAVAILABLE',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAvailable
                                    ? 'Accepting appointments'
                                    : 'Not accepting appointments',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isAvailable,
                          activeThumbColor: Colors.white,
                          activeTrackColor:
                              Colors.greenAccent.withValues(alpha: 0.6),
                          onChanged: (val) {
                            setState(
                                () => _availability['is_available'] = val);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Session Info Card ──
                  _buildInfoCard(
                    title: 'Session Information',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _infoRow(Icons.local_hospital_rounded, 'Clinic',
                          _availability['clinic'] ?? 'General OPD'),
                      _infoRow(Icons.wb_sunny_rounded, 'Session Type',
                          _availability['session_type'] ?? 'Morning Session'),
                      _infoRow(Icons.schedule_rounded, 'Start Time',
                          _availability['working_hours_start'] ?? '08:00 AM'),
                      _infoRow(Icons.schedule_outlined, 'End Time',
                          _availability['working_hours_end'] ?? '04:00 PM'),
                      _infoRow(Icons.people_rounded, 'Max Patients/Day',
                          '${_availability['max_patients_per_day'] ?? 40}'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Working Days ──
                  Container(
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
                            Icon(Icons.calendar_month_rounded,
                                size: 18, color: AppTheme.doctorPrimaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Working Days',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allDays.map((day) {
                            final selected = _workingDays.contains(day);
                            return FilterChip(
                              label: Text(
                                day.substring(0, 3), // Mon, Tue, etc.
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? AppTheme.doctorPrimaryColor
                                        : AppTheme.mutedText),
                              ),
                              selected: selected,
                              onSelected: (_) => _toggleDay(day),
                              selectedColor: AppTheme.doctorPrimaryColor
                                  .withValues(alpha: 0.12),
                              checkmarkColor: AppTheme.doctorPrimaryColor,
                              side: BorderSide(
                                  color: selected
                                      ? AppTheme.doctorPrimaryColor
                                          .withValues(alpha: 0.5)
                                      : Colors.grey.shade300),
                              backgroundColor: Colors.white,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Save Button ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save Availability'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: const Color(0xFF10B981)),
                      onPressed: _isSaving ? null : _saveAvailability,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
      bottomNavigationBar: const DoctorBottomNavBar(currentIndex: 3),
    );
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.doctorPrimaryColor),
          const SizedBox(width: 10),
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
