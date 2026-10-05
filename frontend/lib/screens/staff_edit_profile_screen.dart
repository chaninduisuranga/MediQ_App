import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';

class StaffEditProfileScreen extends StatefulWidget {
  const StaffEditProfileScreen({super.key});

  @override
  State<StaffEditProfileScreen> createState() => _StaffEditProfileScreenState();
}

class _StaffEditProfileScreenState extends State<StaffEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _nameController = TextEditingController(
        text: user?['full_name']?.toString() ?? '');
    _phoneController = TextEditingController(
        text: user?['phone']?.toString() ?? '');
    _emailController = TextEditingController(
        text: user?['email']?.toString() ?? '');
    _addressController =
        TextEditingController(text: user?['address']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: '',
        dateOfBirth: '',
        civilStatus: '',
        address: _addressController.text.trim(),
        district: '',
        emergencyContactName: '',
        emergencyContactPhone: '',
        bloodGroup: '',
        allergies: '',
        medicalConditions: '',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff profile updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to update Staff profile.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update Staff profile: $error'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Staff Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Avatar Card
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor:
                          AppTheme.primarySkyBlue.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: AppTheme.primarySkyBlue,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.primarySkyBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 24),

              // 3. Editable Profile Information Card
              Container(
                width: double.infinity,
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
                    const Text(
                      'Editable Contact & Bio Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Full Name
                    const Text(
                      'Full Name',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            color: AppTheme.primarySkyBlue),
                        hintText: 'e.g. Chaminda Bandara',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Phone Number
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
                          return 'Please enter your contact number';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.phone_outlined,
                            color: AppTheme.primarySkyBlue),
                        hintText: 'e.g. 0772223334',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Email Address
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
                      readOnly: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined,
                            color: AppTheme.primarySkyBlue),
                        hintText: 'e.g. staff.opd@mediq.lk',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Address
                    const Text(
                      'Station / Unit Address',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_outlined,
                            color: AppTheme.primarySkyBlue),
                        hintText: 'e.g. National Hospital OPD Unit',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 4. Save Changes Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primarySkyBlue.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primarySkyBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleSave,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'SAVE PROFILE CHANGES',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // 5. Cancel Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
