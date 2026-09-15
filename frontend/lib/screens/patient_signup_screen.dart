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
  final _emailController = TextEditingController();
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
    _emailController.dispose();
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
      email: _emailController.text,
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
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: const Text(
          'Patient Registration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.darkText),
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
            // Interactive 4-Step Progress Stepper Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primarySkyBlue.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: List.generate(4, (index) {
                      final isCompleted = index < _currentStep;
                      final isCurrent = index == _currentStep;
                      return Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCompleted
                                          ? AppTheme.primarySkyBlue
                                          : (isCurrent
                                              ? AppTheme.lightSkyBlue
                                              : const Color(0xFFE2E8F0)),
                                      border: isCurrent
                                          ? Border.all(color: AppTheme.primarySkyBlue, width: 2)
                                          : null,
                                      boxShadow: isCurrent
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.primarySkyBlue.withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: isCompleted
                                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                          : Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: (isCurrent || isCompleted) ? Colors.white : AppTheme.mutedText,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getShortStepTitle(index),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                      color: isCurrent ? AppTheme.primarySkyBlue : AppTheme.mutedText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (index < 3)
                              Expanded(
                                child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.only(bottom: 14),
                                  color: isCompleted ? AppTheme.primarySkyBlue : const Color(0xFFE2E8F0),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.all(18),
                child: Card(
                  elevation: 2,
                  shadowColor: AppTheme.primarySkyBlue.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStepTitle(_currentStep),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primarySkyBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        IndexedStack(
                          index: _currentStep,
                          children: [
                            _buildStep1Personal(),
                            _buildStep2Contact(),
                            _buildStep3Medical(),
                            _buildStep4Security(),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Back', style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primarySkyBlue.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading
                            ? null
                            : (_currentStep == 3 ? _handleSignup : _nextStep),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                _currentStep == 3 ? 'Complete Registration' : 'Next Step',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
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

  String _getShortStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal';
      case 1:
        return 'Contact';
      case 2:
        return 'Medical';
      case 3:
        return 'Security';
      default:
        return '';
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Personal Info (පෞද්ගලික විස්තර)';
      case 1:
        return 'Contact Details (සම්බන්ධතා)';
      case 2:
        return 'Medical History (සෞඛ්‍ය විස්තර)';
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
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primarySkyBlue),
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
              prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primarySkyBlue),
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
                        prefixIcon: Icon(Icons.calendar_today_outlined, color: AppTheme.primarySkyBlue),
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
                        prefixIcon: Icon(Icons.people_outline_rounded, color: AppTheme.primarySkyBlue),
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
                        prefixIcon: Icon(Icons.favorite_outline_rounded, color: AppTheme.primarySkyBlue),
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
              prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primarySkyBlue),
            ),
          ),
          const SizedBox(height: 16),

          const Text('Email Address (විද්‍යුත් තැපෑල)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(v.trim())) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
            decoration: const InputDecoration(
              hintText: 'e.g. patient@example.com',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primarySkyBlue),
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
              prefixIcon: Icon(Icons.home_outlined, color: AppTheme.primarySkyBlue),
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
              prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primarySkyBlue),
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.contact_emergency_rounded, color: AppTheme.primarySkyBlue, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Emergency Contact Person',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                const Text('Contact Name (නම)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emergencyNameController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Emergency contact name required' : null,
                  decoration: const InputDecoration(
                    hintText: 'e.g. N. Perera (Spouse/Parent)',
                    prefixIcon: Icon(Icons.contact_phone_outlined, color: AppTheme.primarySkyBlue),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Emergency Phone (දුරකථන අංකය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().length < 9 ? 'Emergency contact phone required' : null,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 0719876543',
                    prefixIcon: Icon(Icons.phone_in_talk_outlined, color: AppTheme.primarySkyBlue),
                  ),
                ),
              ],
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
          const SizedBox(height: 10),
          
          // Blood Group Grid Selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bloodGroups.map((bg) {
              final isSelected = _selectedBloodGroup == bg;
              return InkWell(
                onTap: () => setState(() => _selectedBloodGroup = bg),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 60,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primarySkyBlue : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primarySkyBlue : const Color(0xFFCBD5E1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primarySkyBlue.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          size: 14,
                          color: isSelected ? Colors.white : AppTheme.errorRed,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          bg,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.darkText,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Known Drug / Food Allergies (අසාත්මිකතා)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _allergiesController,
            decoration: const InputDecoration(
              hintText: 'e.g. Penicillin, Aspirin, Seafood, None',
              prefixIcon: Icon(Icons.warning_amber_rounded, color: AppTheme.primarySkyBlue),
            ),
          ),
          const SizedBox(height: 20),

          const Text('Pre-existing Medical Conditions / Chronic Diseases (පවතින රෝගී තත්ත්වයන්)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonConditions.map((cond) {
              final isSelected = _selectedConditions.contains(cond);
              return FilterChip(
                label: Text(cond),
                selected: isSelected,
                selectedColor: AppTheme.primarySkyBlue.withValues(alpha: 0.15),
                checkmarkColor: AppTheme.primarySkyBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primarySkyBlue : const Color(0xFFCBD5E1),
                  ),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primarySkyBlue : AppTheme.darkText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
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
          const SizedBox(height: 16),

          const Text('Other Medical Conditions / Notes (වෙනත් සෞඛ්‍ය විස්තර)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _medicalConditionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Any other surgeries, long term medications, or notes',
              prefixIcon: Icon(Icons.medical_information_outlined, color: AppTheme.primarySkyBlue),
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
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkText),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your password will be used along with your NIC to log into the MediQ Portal.',
            style: TextStyle(fontSize: 13, color: AppTheme.mutedText, height: 1.3),
          ),
          const SizedBox(height: 20),

          const Text('Password (මුරපදය)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
            decoration: InputDecoration(
              hintText: 'At least 6 characters',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primarySkyBlue),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.mutedText),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 16),

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
              prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppTheme.primarySkyBlue),
              suffixIcon: IconButton(
                icon: Icon(_isConfirmPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppTheme.mutedText),
                onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

