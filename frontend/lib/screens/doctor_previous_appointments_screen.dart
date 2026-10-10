import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';
import '../widgets/doctor_bottom_nav_bar.dart';

class DoctorPreviousAppointmentsScreen extends StatefulWidget {
  const DoctorPreviousAppointmentsScreen({super.key});

  @override
  State<DoctorPreviousAppointmentsScreen> createState() =>
      _DoctorPreviousAppointmentsScreenState();
}

class _DoctorPreviousAppointmentsScreenState
    extends State<DoctorPreviousAppointmentsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];
  String _activeFilter = 'ALL';

  static const _filters = ['ALL', 'COMPLETED', 'NO_SHOW'];
  static const _filterLabels = {
    'ALL': 'All',
    'COMPLETED': 'Completed',
    'NO_SHOW': 'No Show',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final list = await DoctorService.getPreviousAppointments();
    if (mounted) setState(() { _appointments = list; _isLoading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_activeFilter == 'ALL') return _appointments;
    return _appointments
        .where((a) => (a['consultation_status'] ??
                    a['appointment_status'] ??
                    a['status'] ??
                    '')
                .toString()
                .toUpperCase() ==
            _activeFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Appointments',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _fetch),
        ],
      ),
      body: Column(
        children: [
          // ── Filters ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final selected = _activeFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_filterLabels[f] ?? f),
                      selected: selected,
                      onSelected: (_) => setState(() => _activeFilter = f),
                      selectedColor:
                          AppTheme.doctorPrimaryColor.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.doctorPrimaryColor,
                      labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.doctorPrimaryColor
                              : AppTheme.mutedText),
                      side: BorderSide(
                          color: selected
                              ? AppTheme.doctorPrimaryColor.withValues(alpha: 0.5)
                              : Colors.grey.shade300),
                      backgroundColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // ── List ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.doctorPrimaryColor))
                : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _fetch,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) =>
                              _buildCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const DoctorBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildCard(Map<String, dynamic> appt) {
    final status = (appt['consultation_status'] ??
            appt['appointment_status'] ??
            appt['status'] ??
            'COMPLETED')
        .toString();
    final statusColor = DoctorService.getStatusColor(status);
    final statusLabel = DoctorService.getStatusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
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
                        '${appt['patient_id'] ?? ''} · ${appt['patient_nic'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.mutedText),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
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
            const SizedBox(height: 12),

            // Details
            Row(
              children: [
                _chip(Icons.today_rounded,
                    appt['appointment_date'] ?? '--'),
                const SizedBox(width: 10),
                _chip(Icons.schedule_rounded,
                    appt['appointment_time'] ?? '--'),
                const SizedBox(width: 10),
                _chip(Icons.confirmation_number_rounded,
                    appt['queue_number'] ?? '--'),
              ],
            ),

            if ((appt['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                appt['notes'] ?? '',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.mutedText, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            OutlinedButton.icon(
              icon: const Icon(Icons.person_search_rounded, size: 16),
              label: const Text('View Patient Details'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => Navigator.pushNamed(
                context,
                '/doctor-patient-detail',
                arguments: appt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.mutedText),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.mutedText)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              size: 64,
              color: AppTheme.mutedText.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'No previous appointments found',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}
