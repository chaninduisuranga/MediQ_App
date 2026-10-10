import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/admin_appointment_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';
import '../widgets/admin_bottom_nav_bar.dart';

class AdminAppointmentManagementScreen extends StatefulWidget {
  const AdminAppointmentManagementScreen({super.key});

  @override
  State<AdminAppointmentManagementScreen> createState() =>
      _AdminAppointmentManagementScreenState();
}

class _AdminAppointmentManagementScreenState
    extends State<AdminAppointmentManagementScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<AdminAppointment> _appointments = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedDate = _formatDate(DateTime.now());
  String _selectedService = '';
  String _selectedStatus = '';

  static const _services = <Map<String, String>>[
    {'key': '', 'label': 'All services'},
    {'key': 'OPD_CLINIC_ROOM', 'label': 'General OPD'},
    {'key': 'DRESSING_ROOM', 'label': 'Dressing'},
    {'key': 'INJECTION_ROOM', 'label': 'Injection'},
    {'key': 'BLEEDING_ROOM', 'label': 'Bleeding'},
    {'key': 'ANIMAL_BITE_ROOM', 'label': 'Animal Bite'},
  ];

  static const _statuses = <Map<String, String>>[
    {'key': '', 'label': 'All statuses'},
    {'key': 'PENDING', 'label': 'Waiting'},
    {'key': 'CONFIRMED', 'label': 'Confirmed'},
    {'key': 'COMPLETED', 'label': 'Completed'},
    {'key': 'CANCELLED', 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await AdminService.getAppointments(
      search: _searchController.text,
      date: _selectedDate,
      service: _selectedService,
      status: _selectedStatus,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _appointments = result['appointments'] as List<AdminAppointment>;
      } else {
        _errorMessage = result['message'] as String?;
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), _loadAppointments);
  }

  Future<void> _pickDate() async {
    final current = DateTime.tryParse(_selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = _formatDate(picked));
    _loadAppointments();
  }

  Future<void> _cancelAppointment(AdminAppointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
            'Cancel ${appointment.patientName}\'s appointment #${appointment.id}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel appointment')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _updateAppointment(appointment.id, status: 'CANCELLED');
  }

  Future<void> _showRescheduleDialog(AdminAppointment appointment) async {
    final dateController = TextEditingController(text: appointment.date);
    final timeController = TextEditingController(text: appointment.time);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: dateController,
                decoration:
                    const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
            const SizedBox(height: 12),
            TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: 'Time (HH:MM)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'date': dateController.text.trim(),
              'time': timeController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    dateController.dispose();
    timeController.dispose();
    if (result == null) return;
    await _updateAppointment(appointment.id,
        date: result['date'], time: result['time']);
  }

  Future<void> _updateAppointment(
    int id, {
    String? date,
    String? time,
    String? status,
  }) async {
    final result = await AdminService.updateAppointment(id,
        date: date, time: time, status: status);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(result['message'] as String? ?? 'Appointment updated')),
    );
    if (result['success'] == true) await _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Management'),
        actions: [
          IconButton(
              onPressed: _loadAppointments,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh appointments'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: Text(_selectedDate),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildFilter(_services, _selectedService, (value) {
                  setState(() => _selectedService = value ?? '');
                  _loadAppointments();
                })),
              ],
            ),
            const SizedBox(height: 10),
            _buildFilter(_statuses, _selectedStatus, (value) {
              setState(() => _selectedStatus = value ?? '');
              _loadAppointments();
            }),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                labelText: 'Search appointments',
                hintText: 'Patient name, NIC, phone, or appointment ID',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              _buildMessage(_errorMessage!, Icons.error_outline_rounded)
            else if (_appointments.isEmpty)
              _buildMessage('No appointments match these filters.',
                  Icons.event_busy_rounded)
            else
              ..._appointments.map(_buildAppointmentCard),
          ],
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildFilter(List<Map<String, String>> options, String value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(isDense: true),
      items: options
          .map((option) => DropdownMenuItem(
              value: option['key'], child: Text(option['label']!)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildAppointmentCard(AdminAppointment appointment) {
    final statusColor = _statusColor(appointment.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(appointment.time.isEmpty ? '--:--' : appointment.time,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(appointment.patientName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold))),
                _buildStatusBadge(appointment.status, statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
                '${appointment.roomDisplayName}  •  Queue #${appointment.queueNumber}',
                style: const TextStyle(color: AppTheme.mutedText)),
            Text(
                'NIC: ${appointment.patientNic}  •  Phone: ${appointment.patientPhone}',
                style: const TextStyle(color: AppTheme.mutedText)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                    onPressed: appointment.status == 'CANCELLED'
                        ? null
                        : () => _showRescheduleDialog(appointment),
                    icon: const Icon(Icons.schedule_rounded),
                    label: const Text('Reschedule')),
                TextButton.icon(
                    onPressed: appointment.status == 'CANCELLED' ||
                            appointment.status == 'COMPLETED'
                        ? null
                        : () => _cancelAppointment(appointment),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Chip(
        label: Text(status,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        backgroundColor: color.withValues(alpha: 0.1),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact);
  }

  Widget _buildMessage(String message, IconData icon) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(icon, size: 48, color: AppTheme.mutedText),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center)
        ]));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'CONFIRMED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
