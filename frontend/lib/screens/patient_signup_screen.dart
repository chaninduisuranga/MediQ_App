import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';

class PatientSignupScreen extends StatefulWidget {
  const PatientSignupScreen({super.key});

  @override
  State<PatientSignupScreen> createState() => _PatientSignupScreenState();
}

class _PatientSignupScreenState extends State<PatientSignupScreen> {
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();
  final _formKeyStep4 = GlobalKey<FormState>();

  // Form Controllers
  final _fullNameController = TextEditingController();
  final _nicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicalConditionsController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Selection States
  String _selectedGender = 'Male';
  String _selectedCivilStatus = 'Single';
  String _selectedDistrict = 'Colombo';
  String _selectedBloodGroup = 'A+';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _districts = [
    'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo',
    'Galle', 'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara',
    'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar',
    'Matale', 'Matara', 'Moneragala', 'Mullaitivu', 'Nuwara Eliya',
    'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya'
  ];

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  final List<String> _commonConditions = ['Diabetes', 'Hypertension', 'Asthma', 'Heart Disease', 'Kidney Disease', 'None'];
  final List<String> _selectedConditions = [];

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryTeal,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  String? _validateNIC(String? value) {
    if (value == null || value.trim().isEmpty) return 'NIC number is required';
    final trimmed = value.trim().toUpperCase();
    final oldNicRegex = RegExp(r'^[0-9]{9}[VX]$');
    final newNicRegex = RegExp(r'^[0-9]{12}$');
    if (!oldNicRegex.hasMatch(trimmed) && !newNicRegex.hasMatch(trimmed)) {
      return 'Valid Sri Lankan NIC required (e.g. 951234567V)';
    }
    return null;
  }

  void _nextStep() {
    bool isStepValid = false;
    if (_currentStep == 0) {
      isStepValid = _formKeyStep1.currentState!.validate();
    } else if (_currentStep == 1) {
      isStepValid = _formKeyStep2.currentState!.validate();
    } else if (_currentStep == 2) {
      isStepValid = _formKeyStep3.currentState!.validate();
    }

    if (isStepValid && _currentStep < 3) {
      setState(() {
        _currentStep++;
        _errorMessage = null;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKeyStep4.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final conditionsStr = _selectedConditions.join(', ') + 
        (_medicalConditionsController.text.isNotEmpty ? ' (${_medicalConditionsController.text})' : '');

    final result = await AuthService.signupPatient(
      fullName: _fullNameController.text,
      nic: _nicController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      gender: _selectedGender,
      dateOfBirth: _dobController.text,
      civilStatus: _selectedCivilStatus,
      address: _addressController.text,
      district: _selectedDistrict,
      emergencyContactName: _emergencyNameController.text,
      emergencyContactPhone: _emergencyPhoneController.text,
      bloodGroup: _selectedBloodGroup,
      allergies: _allergiesController.text.isEmpty ? 'None' : _allergiesController.text,
      medicalConditions: conditionsStr.isEmpty ? 'None' : conditionsStr,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Patient registration successful!'),
          backgroundColor: AppTheme.primaryTeal,
        ),
      );
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_currentStep > 0) {
              _prevStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of 4: ${_getStepTitle(_currentStep)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      Text(
                        '${((_currentStep + 1) / 4 * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / 4,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryTeal),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: IndexedStack(
                  index: _currentStep,
                  children: [
                    _buildStep1Personal(),
                    _buildStep2Contact(),
                    _buildStep3Medical(),
                    _buildStep4Security(),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep == 3 ? _handleSignup : _nextStep),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(_currentStep == 3 ? 'Complete Registration' : 'Next Step'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Info (පෞද්ගලික විස්තර)';
      case 1:
        return 'Contact Details (සම්බන්ධතා)';
      case 2:
        return 'Medical History (සෞඛ්‍ය)';
      case 3:
        return 'Account Security (ආරක්ෂාව)';
      default:
        return '';
    }
  }

  // STEP 1: Personal Info
  Widget _buildStep1Personal() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Full Name (සම්පූර්ණ නම)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _fullNameController,
            validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. K.A. Sunimal Perera',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 16),

          const Text('NIC Number (ජාතික හැඳුනුම්පත් අංකය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _nicController,
            textCapitalization: TextCapitalization.characters,
            validator: _validateNIC,
            decoration: const InputDecoration(
              hintText: 'e.g. 199512345V or 199512345678',
              prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Date of Birth (උපන් දිනය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      onTap: _selectDateOfBirth,
                      validator: (v) => v == null || v.isEmpty ? 'Select DOB' : null,
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today_outlined, color: AppTheme.primaryTeal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Gender (ස්ත්‍රී / පුරුෂ)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (v) => setState(() => _selectedGender = v!),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.people_outline_rounded, color: AppTheme.primaryTeal),
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
                    const Text('Civil Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCivilStatus,
                      items: ['Single', 'Married', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _selectedCivilStatus = v!),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.favorite_outline_rounded, color: AppTheme.primaryTeal),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // STEP 2: Contact Details
  Widget _buildStep2Contact() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mobile Phone Number (දුරකථන අංකය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.trim().length < 9 ? 'Enter valid phone number (e.g. 0771234567)' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. 0771234567',
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Residential Address (ලිපිනය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
            decoration: const InputDecoration(
              hintText: 'House No, Street Name, Town',
              prefixIcon: Icon(Icons.home_outlined, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 16),

          const Text('District (දිස්ත්‍රික්කය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedDistrict,
            items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _selectedDistrict = v!),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 20),

          const Divider(),
          const SizedBox(height: 10),
          const Text(
            'Emergency Contact Person (හදිසි අවස්ථාවකදී ඇමතිය යුතු අයගේ විස්තර)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 12),

          const Text('Contact Name (නම)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emergencyNameController,
            validator: (v) => v == null || v.trim().isEmpty ? 'Emergency contact name required' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. N. Perera (Spouse/Parent)',
              prefixIcon: Icon(Icons.contact_phone_outlined, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Emergency Phone (දුරකථන අංකය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emergencyPhoneController,
            keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.trim().length < 9 ? 'Emergency contact phone required' : null,
            decoration: const InputDecoration(
              hintText: 'e.g. 0719876543',
              prefixIcon: Icon(Icons.phone_in_talk_outlined, color: AppTheme.primaryTeal),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 3: Medical History
  Widget _buildStep3Medical() {
    return Form(
      key: _formKeyStep3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Blood Group (ලේ වර්ගය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedBloodGroup,
            items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
            onChanged: (v) => setState(() => _selectedBloodGroup = v!),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.water_drop_outlined, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 18),

          const Text('Known Drug / Food Allergies (අසාත්මිකතා)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _allergiesController,
            decoration: const InputDecoration(
              hintText: 'e.g. Penicillin, Aspirin, Seafood, None',
              prefixIcon: Icon(Icons.warning_amber_rounded, color: AppTheme.primaryTeal),
            ),
          ),
          const SizedBox(height: 18),

          const Text('Pre-existing Medical Conditions / Chronic Diseases (පවතින රෝගී තත්ත්වයන්)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _commonConditions.map((cond) {
              final isSelected = _selectedConditions.contains(cond);
              return FilterChip(
                label: Text(cond),
                selected: isSelected,
                selectedColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                checkmarkColor: AppTheme.primaryTeal,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryTeal : AppTheme.darkText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (cond == 'None') {
                      _selectedConditions.clear();
                      if (selected) _selectedConditions.add('None');
                    } else {
                      _selectedConditions.remove('None');
                      if (selected) {
                        _selectedConditions.add(cond);
                      } else {
                        _selectedConditions.remove(cond);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          const Text('Other Medical Conditions / Notes (වෙනත් සෞඛ්‍ය විස්තර)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _medicalConditionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Any other surgeries, long term medications, or notes',
              prefixIcon: Icon(Icons.medical_information_outlined, color: AppTheme.primaryTeal),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 4: Security & Password
  Widget _buildStep4Security() {
    return Form(
      key: _formKeyStep4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Your OPD Account Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your password will be used along with your NIC to log in.',
            style: TextStyle(fontSize: 13, color: AppTheme.mutedText),
          ),
          const SizedBox(height: 24),

          const Text('Password (මුරපදය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryTeal),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 18),

          const Text('Confirm Password (මුරපදය තහවුරු කරන්න)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.primaryTeal),
              suffixIcon: IconButton(
                icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
