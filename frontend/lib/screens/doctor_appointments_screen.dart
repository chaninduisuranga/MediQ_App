import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';
import '../widgets/doctor_bottom_nav_bar.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAppointments = [];
  String _activeFilter = 'ALL';

  static const _filters = ['ALL', 'WAITING', 'IN_CONSULTATION', 'COMPLETED', 'CANCELLED'];
  static const _filterLabels = {
    'ALL': 'All',
    'WAITING': 'Waiting',
    'IN_CONSULTATION': 'In Consultation',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    final list = await DoctorService.getTodayAppointments();
    if (mounted) {
      setState(() {
        _allAppointments = list;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_activeFilter == 'ALL') return _allAppointments;
    return _allAppointments.where((a) {
      if (_activeFilter == 'WAITING') {
        return DoctorService.isAppointmentWaiting(a);
      }
      if (_activeFilter == 'IN_CONSULTATION') {
        return DoctorService.isAppointmentInConsultation(a);
      }
      return [
        a['appointment_status'],
        a['consultation_status'],
        a['queue_status'],
        a['status'],
      ].any(
          (status) => status?.toString().trim().toUpperCase() == _activeFilter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Appointments",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAppointments,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final selected = _activeFilter == f;
                  final color = _filterColor(f);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabels[f] ?? f),
                      selected: selected,
                      onSelected: (_) => setState(() => _activeFilter = f),
                      selectedColor: color.withValues(alpha: 0.15),
                      checkmarkColor: color,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : AppTheme.mutedText,
                      ),
                      side: BorderSide(
                          color: selected
                              ? color.withValues(alpha: 0.5)
                              : Colors.grey.shade300),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── Appointment List ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.doctorPrimaryColor))
                : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _fetchAppointments,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) =>
                              _buildAppointmentCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const DoctorBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final status = (appt['appointment_status'] ?? 'SCHEDULED').toString();
    final statusColor = DoctorService.getStatusColor(status);
    final displayStatus = DoctorService.getStatusLabel(status);
    final isActive = DoctorService.isAppointmentInConsultation(appt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.doctorPrimaryColor.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Queue number badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        appt['queue_number'] ?? '--',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ],
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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${appt['patient_id'] ?? ''} · Age ${appt['patient_age'] ?? '--'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.mutedText),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 14, color: AppTheme.mutedText),
                const SizedBox(width: 4),
                Text(
                  appt['appointment_time'] ?? '--',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.mutedText),
                ),
                const SizedBox(width: 14),
                const Icon(Icons.wc_rounded,
                    size: 14, color: AppTheme.mutedText),
                const SizedBox(width: 4),
                Text(
                  appt['patient_gender'] ?? '--',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.mutedText),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _actionButton(
                  label: 'View Patient',
                  icon: Icons.person_search_rounded,
                  color: AppTheme.doctorPrimaryColor,
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/doctor-patient-detail',
                    arguments: appt,
                  ),
                ),
                if (status == 'WAITING' ||
                    (appt['queue_status'] ?? '').toString() == 'CHECKED_IN')
                  _actionButton(
                    label: 'Start Consultation',
                    icon: Icons.medical_services_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/doctor-consultation',
                      arguments: appt,
                    ),
                  ),
                if (status == 'IN_CONSULTATION' ||
                    (appt['queue_status'] ?? '').toString() == 'IN_PROGRESS')
                  _actionButton(
                    label: 'Continue',
                    icon: Icons.play_circle_rounded,
                    color: AppTheme.doctorPrimaryColor,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/doctor-consultation',
                      arguments: appt,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_rounded,
              size: 64,
              color: AppTheme.mutedText.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _activeFilter == 'ALL'
                ? 'No appointments today'
                : 'No ${_filterLabels[_activeFilter]} appointments',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }

  Color _filterColor(String f) {
    switch (f) {
      case 'WAITING':
        return const Color(0xFFF59E0B);
      case 'IN_CONSULTATION':
        return AppTheme.doctorPrimaryColor;
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CANCELLED':
        return AppTheme.errorRed;
      default:
        return AppTheme.mutedText;
    }
  }
}
