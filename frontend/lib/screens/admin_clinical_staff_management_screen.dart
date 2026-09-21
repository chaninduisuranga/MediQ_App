import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models/admin_doctor_model.dart';
import '../core/models/admin_staff_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';

class AdminClinicalStaffManagementScreen extends StatefulWidget {
  const AdminClinicalStaffManagementScreen({super.key});

  @override
  State<AdminClinicalStaffManagementScreen> createState() =>
      _AdminClinicalStaffManagementScreenState();
}

class _AdminClinicalStaffManagementScreenState
    extends State<AdminClinicalStaffManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<AdminDoctor> _doctors = [];
  List<AdminStaff> _staff = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const rooms = <Map<String, String>>[
    {'key': '', 'label': 'Unassigned'},
    {'key': 'OPD_CLINIC_ROOM', 'label': 'General OPD'},
    {'key': 'DRESSING_ROOM', 'label': 'Dressing Room'},
    {'key': 'INJECTION_ROOM', 'label': 'Injection Room'},
    {'key': 'BLEEDING_ROOM', 'label': 'Bleeding Room'},
    {'key': 'ANIMAL_BITE_ROOM', 'label': 'Animal Bite Room'},
  ];

  static const staffFunctions = <Map<String, String>>[
    {'key': 'REGISTRATION', 'label': 'Registration'},
    {'key': 'NURSE', 'label': 'Nurse'},
    {'key': 'QUEUE_MANAGEMENT', 'label': 'Queue management'},
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadCurrentTab();
    });
    _loadCurrentTab();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTab() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = _tabs.index == 0
        ? await AdminService.getDoctors(search: _searchController.text)
        : await AdminService.getStaff(search: _searchController.text);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        if (_tabs.index == 0) {
          _doctors = result['doctors'] as List<AdminDoctor>;
        } else {
          _staff = result['staff'] as List<AdminStaff>;
        }
      } else {
        _errorMessage = result['message'] as String?;
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadCurrentTab);
  }

  Future<void> _openDoctorForm([AdminDoctor? doctor]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DoctorForm(doctor: doctor),
    );
    if (result == null) return;
    final response = doctor == null
        ? await AdminService.createDoctor(
            userId: result['user_id'],
            specialization: result['specialization'],
            slmcNumber: result['slmc_number'],
            clinicName: result['clinic_name'],
            room: result['room'],
            isAvailable: result['is_available'],
          )
        : await AdminService.updateDoctor(
            doctor.id,
            userId: doctor.userId,
            specialization: result['specialization'],
            slmcNumber: result['slmc_number'],
            clinicName: result['clinic_name'],
            room: result['room'],
            isAvailable: result['is_available'],
            status: result['status'],
          );
    _showResult(response);
  }

  Future<void> _openStaffForm([AdminStaff? staff]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _StaffForm(staff: staff),
    );
    if (result == null) return;
    final response = staff == null
        ? await AdminService.createStaff(
            userId: result['user_id'],
            function: result['function'],
            assignedRoom: result['assigned_room'],
            isAvailable: result['is_available'],
          )
        : await AdminService.updateStaff(
            staff.id,
            userId: staff.userId,
            function: result['function'],
            assignedRoom: result['assigned_room'],
            isAvailable: result['is_available'],
            status: result['status'],
          );
    _showResult(response);
  }

  void _showResult(Map<String, dynamic> result) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] as String? ?? 'Saved')),
    );
    if (result['success'] == true) _loadCurrentTab();
  }

  @override
  Widget build(BuildContext context) {
    final isDoctorTab = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor & Staff Management'),
        actions: [
          IconButton(
            onPressed: _loadCurrentTab,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Doctors'), Tab(text: 'Staff')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            isDoctorTab ? () => _openDoctorForm() : () => _openStaffForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(isDoctorTab ? 'Add doctor' : 'Add staff'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentTab,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: isDoctorTab ? 'Search doctors' : 'Search staff',
                hintText: isDoctorTab
                    ? 'Name, specialization, or SLMC number'
                    : 'Name or staff function',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _message(_errorMessage!, Icons.error_outline_rounded)
            else if ((isDoctorTab && _doctors.isEmpty) ||
                (!isDoctorTab && _staff.isEmpty))
              _message(
                isDoctorTab
                    ? 'No doctor profiles found.'
                    : 'No staff profiles found.',
                Icons.people_outline_rounded,
              )
            else if (isDoctorTab)
              ..._doctors.map(_doctorCard)
            else
              ..._staff.map(_staffCard),
          ],
        ),
      ),
    );
  }

  Widget _doctorCard(AdminDoctor doctor) => _profileCard(
        title: doctor.name,
        subtitle: '${doctor.specialization}  •  ${_roomLabel(doctor.room)}',
        details:
            'Current queue: ${doctor.currentQueue}  •  SLMC: ${doctor.slmcNumber}',
        status: doctor.status,
        availability: doctor.isAvailable,
        onEdit: () => _openDoctorForm(doctor),
      );

  Widget _staffCard(AdminStaff staff) => _profileCard(
        title: staff.name,
        subtitle:
            '${_functionLabel(staff.function)}  •  ${_roomLabel(staff.assignedRoom)}',
        details:
            'Availability: ${staff.isAvailable ? 'Available' : 'Unavailable'}',
        status: staff.status,
        availability: staff.isAvailable,
        onEdit: () => _openStaffForm(staff),
      );

  Widget _profileCard({
    required String title,
    required String subtitle,
    required String details,
    required String status,
    required bool availability,
    required VoidCallback onEdit,
  }) {
    final statusColor = status == 'ACTIVE' ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
          child: const Icon(Icons.person_rounded, color: AppTheme.primaryTeal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              '$subtitle\n$details\nStatus: $status  •  ${availability ? 'Available' : 'Unavailable'}',
              style: TextStyle(color: statusColor)),
        ),
        isThreeLine: true,
        trailing: IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Edit',
        ),
      ),
    );
  }

  Widget _message(String message, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppTheme.mutedText),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      );

  String _roomLabel(String key) => rooms.firstWhere(
        (item) => item['key'] == key,
        orElse: () => {'label': key.isEmpty ? 'Unassigned' : key},
      )['label']!;

  String _functionLabel(String key) => staffFunctions.firstWhere(
        (item) => item['key'] == key,
        orElse: () => {'label': key},
      )['label']!;
}

class _DoctorForm extends StatefulWidget {
  const _DoctorForm({this.doctor});
  final AdminDoctor? doctor;

  @override
  State<_DoctorForm> createState() => _DoctorFormState();
}

class _DoctorFormState extends State<_DoctorForm> {
  late final TextEditingController _userId;
  late final TextEditingController _specialization;
  late final TextEditingController _slmc;
  late final TextEditingController _clinic;
  String _room = '';
  String _status = 'ACTIVE';
  bool _available = true;

  @override
  void initState() {
    super.initState();
    final doctor = widget.doctor;
    _userId = TextEditingController(text: doctor?.userId.toString() ?? '');
    _specialization = TextEditingController(text: doctor?.specialization ?? '');
    _slmc = TextEditingController(text: doctor?.slmcNumber ?? '');
    _clinic = TextEditingController(text: doctor?.clinicName ?? '');
    _room = doctor?.room ?? '';
    _status = doctor?.status ?? 'ACTIVE';
    _available = doctor?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _userId.dispose();
    _specialization.dispose();
    _slmc.dispose();
    _clinic.dispose();
    super.dispose();
  }

  void _submit() {
    final userId = int.tryParse(_userId.text.trim());
    if (userId == null ||
        _specialization.text.trim().isEmpty ||
        _slmc.text.trim().isEmpty ||
        _clinic.text.trim().isEmpty) {
      return;
    }
    Navigator.pop(context, {
      'user_id': userId,
      'specialization': _specialization.text.trim(),
      'slmc_number': _slmc.text.trim(),
      'clinic_name': _clinic.text.trim(),
      'room': _room,
      'is_available': _available,
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title:
            Text(widget.doctor == null ? 'Add doctor profile' : 'Edit doctor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: _userId,
                  keyboardType: TextInputType.number,
                  enabled: widget.doctor == null,
                  decoration: const InputDecoration(
                      labelText: 'Existing doctor User ID')),
              TextField(
                  controller: _specialization,
                  decoration:
                      const InputDecoration(labelText: 'Specialization')),
              TextField(
                  controller: _slmc,
                  decoration: const InputDecoration(labelText: 'SLMC number')),
              TextField(
                  controller: _clinic,
                  decoration: const InputDecoration(labelText: 'Clinic name')),
              _roomDropdown(),
              SwitchListTile(
                  value: _available,
                  onChanged: (value) => setState(() => _available = value),
                  title: const Text('Available for work')),
              if (widget.doctor != null) _statusDropdown(),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      );

  Widget _roomDropdown() => DropdownButtonFormField<String>(
        initialValue: _room,
        decoration: const InputDecoration(labelText: 'Assigned room'),
        items: _AdminClinicalStaffManagementScreenState.rooms
            .map((item) => DropdownMenuItem(
                value: item['key'], child: Text(item['label']!)))
            .toList(),
        onChanged: (value) => setState(() => _room = value ?? ''),
      );

  Widget _statusDropdown() => DropdownButtonFormField<String>(
        initialValue: _status,
        decoration: const InputDecoration(labelText: 'Account status'),
        items: const ['ACTIVE', 'INACTIVE', 'SUSPENDED']
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (value) => setState(() => _status = value ?? 'ACTIVE'),
      );
}

class _StaffForm extends StatefulWidget {
  const _StaffForm({this.staff});
  final AdminStaff? staff;

  @override
  State<_StaffForm> createState() => _StaffFormState();
}

class _StaffFormState extends State<_StaffForm> {
  late final TextEditingController _userId;
  String _function = 'REGISTRATION';
  String _room = '';
  String _status = 'ACTIVE';
  bool _available = true;

  @override
  void initState() {
    super.initState();
    final staff = widget.staff;
    _userId = TextEditingController(text: staff?.userId.toString() ?? '');
    _function = staff?.function ?? 'REGISTRATION';
    _room = staff?.assignedRoom ?? '';
    _status = staff?.status ?? 'ACTIVE';
    _available = staff?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _userId.dispose();
    super.dispose();
  }

  void _submit() {
    final userId = int.tryParse(_userId.text.trim());
    if (userId == null) return;
    Navigator.pop(context, {
      'user_id': userId,
      'function': _function,
      'assigned_room': _room,
      'is_available': _available,
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.staff == null ? 'Add staff profile' : 'Edit staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _userId,
                keyboardType: TextInputType.number,
                enabled: widget.staff == null,
                decoration:
                    const InputDecoration(labelText: 'Existing staff User ID')),
            DropdownButtonFormField<String>(
                initialValue: _function,
                decoration: const InputDecoration(labelText: 'Staff function'),
                items: _AdminClinicalStaffManagementScreenState.staffFunctions
                    .map((item) => DropdownMenuItem(
                        value: item['key'], child: Text(item['label']!)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _function = value ?? 'REGISTRATION')),
            DropdownButtonFormField<String>(
                initialValue: _room,
                decoration:
                    const InputDecoration(labelText: 'Assigned room/service'),
                items: _AdminClinicalStaffManagementScreenState.rooms
                    .map((item) => DropdownMenuItem(
                        value: item['key'], child: Text(item['label']!)))
                    .toList(),
                onChanged: (value) => setState(() => _room = value ?? '')),
            SwitchListTile(
                value: _available,
                onChanged: (value) => setState(() => _available = value),
                title: const Text('Available for work')),
            if (widget.staff != null)
              DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration:
                      const InputDecoration(labelText: 'Account status'),
                  items: const ['ACTIVE', 'INACTIVE', 'SUSPENDED']
                      .map((item) =>
                          DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'ACTIVE')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      );
}
