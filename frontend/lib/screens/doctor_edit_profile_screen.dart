import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';

class DoctorEditProfileScreen extends StatefulWidget {
  const DoctorEditProfileScreen({super.key});

  @override
  State<DoctorEditProfileScreen> createState() =>
      _DoctorEditProfileScreenState();
}

class _DoctorEditProfileScreenState extends State<DoctorEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();

  String _selectedRoom = 'GENERAL_OPD';
  bool _isLoading = true;
  bool _isSaving = false;

  static const _roomOptions = [
    {'key': 'GENERAL_OPD', 'name': 'General OPD'},
    {'key': 'OPD_CLINIC_ROOM', 'name': 'OPD Clinic Room'},
    {'key': 'DRESSING_ROOM', 'name': 'Dressing Room'},
    {'key': 'INJECTION_ROOM', 'name': 'Injection Room'},
    {'key': 'BLEEDING_ROOM', 'name': 'Bleeding Room'},
    {'key': 'ANIMAL_BITE_ROOM', 'name': 'Animal Bite Room'},
    {'key': 'PHARMACY', 'name': 'Dispensary / Pharmacy'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await DoctorService.getProfile();
    final user = AuthService.currentUser ?? {};

    if (mounted) {
      setState(() {
        _isLoading = false;
        _emailController.text = data['email'] ?? user['email'] ?? '';
        _phoneController.text = data['phone'] ?? user['phone'] ?? '';
        _departmentController.text =
            data['specialization'] ?? data['department'] ?? user['specialization'] ?? 'General Physician';
        
        final roomKey = (data['room'] ?? user['room'] ?? 'GENERAL_OPD').toString().toUpperCase();
        if (_roomOptions.any((r) => r['key'] == roomKey)) {
          _selectedRoom = roomKey;
        } else {
          _selectedRoom = 'GENERAL_OPD';
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final res = await DoctorService.updateProfile(
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      department: _departmentController.text.trim(),
      room: _selectedRoom,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        // Update local user state
        final currentUser = Map<String, dynamic>.from(AuthService.currentUser ?? {});
        currentUser['email'] = _emailController.text.trim();
        currentUser['phone'] = _phoneController.text.trim();
        currentUser['specialization'] = _departmentController.text.trim();
        currentUser['department'] = _departmentController.text.trim();
        currentUser['room'] = _selectedRoom;
        AuthService.updateUserLocal(currentUser);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doctor profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Could not update profile.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Doctor Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.doctorPrimaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.doctorPrimaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.doctorPrimaryColor.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.edit_note_rounded,
                              color: AppTheme.doctorPrimaryColor, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Update Contact & Professional Info',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Changes will be updated in the hospital database.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Form container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email
                          const Text(
                            'Email Address',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!val.contains('@')) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined,
                                  color: AppTheme.doctorPrimaryColor),
                              hintText: 'doctor@mediq.lk',
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Phone
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your phone number';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.phone_outlined,
                                  color: AppTheme.doctorPrimaryColor),
                              hintText: '+94 77 123 4567',
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Department / Specialization
                          const Text(
                            'Department / Specialization',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _departmentController,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your department or specialization';
                              }
                              return null;
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.domain_rounded,
                                  color: AppTheme.doctorPrimaryColor),
                              hintText: 'e.g. General Physician, Cardiology',
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Default OPD Room
                          const Text(
                            'Default OPD Room',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedRoom,
                            items: _roomOptions.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['key'],
                                child: Text(r['name']!),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRoom = val);
                              }
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.meeting_room_outlined,
                                  color: AppTheme.doctorPrimaryColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: const Text('SAVE CHANGES',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.doctorPrimaryColor,
                        ),
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
