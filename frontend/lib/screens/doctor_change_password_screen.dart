import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';

class DoctorChangePasswordScreen extends StatefulWidget {
  const DoctorChangePasswordScreen({super.key});

  @override
  State<DoctorChangePasswordScreen> createState() =>
      _DoctorChangePasswordScreenState();
}

class _DoctorChangePasswordScreenState
    extends State<DoctorChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentObscured = true;
  bool _isNewObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await DoctorService.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Could not change password.'),
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
          'Change Password',
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
              // Security info header
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
                    Icon(Icons.shield_outlined,
                        color: AppTheme.doctorPrimaryColor, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doctor Portal Security',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Create a strong password with at least 6 characters.',
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

              // Password Form Container
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
                    // Current Password
                    const Text(
                      'Current Password',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _isCurrentObscured,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline_rounded,
                            color: AppTheme.doctorPrimaryColor),
                        hintText: 'Enter current password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isCurrentObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.mutedText,
                          ),
                          onPressed: () {
                            setState(
                                () => _isCurrentObscured = !_isCurrentObscured);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // New Password
                    const Text(
                      'New Password',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _isNewObscured,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter a new password';
                        }
                        if (val.length < 6) {
                          return 'Password must be at least 6 characters long';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_reset_rounded,
                            color: AppTheme.doctorPrimaryColor),
                        hintText: 'Enter new password (min. 6 chars)',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isNewObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.mutedText,
                          ),
                          onPressed: () {
                            setState(() => _isNewObscured = !_isNewObscured);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Confirm New Password
                    const Text(
                      'Confirm New Password',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkText),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _isConfirmObscured,
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (val != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded,
                            color: AppTheme.doctorPrimaryColor),
                        hintText: 'Re-enter new password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmObscured
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppTheme.mutedText,
                          ),
                          onPressed: () {
                            setState(() =>
                                _isConfirmObscured = !_isConfirmObscured);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Change Password Button
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.doctorPrimaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.doctorPrimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleChangePassword,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'CHANGE PASSWORD',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel Button
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
