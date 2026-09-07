import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';

class PatientProfileScreen extends StatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  State<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends State<PatientProfileScreen> {
  bool _isLoading = false;

  void _showEditProfileSheet() {
    final user = AuthService.currentUser ?? {};

    final fullNameController = TextEditingController(text: user['full_name'] ?? '');
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    final addressController = TextEditingController(text: user['address'] ?? '');
    final emergencyNameController = TextEditingController(text: user['emergency_contact_name'] ?? '');
    final emergencyPhoneController = TextEditingController(text: user['emergency_contact_phone'] ?? '');
    final allergiesController = TextEditingController(text: user['allergies'] ?? '');
    final medicalConditionsController = TextEditingController(text: user['medical_conditions'] ?? '');

    String selectedGender = user['gender'] ?? 'Male';
    String selectedCivilStatus = user['civil_status'] ?? 'Single';
    String selectedDistrict = user['district'] ?? 'Colombo';
    String selectedBloodGroup = user['blood_group'] ?? 'A+';

    final List<String> districts = [
      'Ampara', 'Anuradhapura', 'Badulla', 'Batticaloa', 'Colombo',
      'Galle', 'Gampaha', 'Hambantota', 'Jaffna', 'Kalutara',
      'Kandy', 'Kegalle', 'Kilinochchi', 'Kurunegala', 'Mannar',
      'Matale', 'Matara', 'Moneragala', 'Mullaitivu', 'Nuwara Eliya',
      'Polonnaruwa', 'Puttalam', 'Ratnapura', 'Trincomalee', 'Vavuniya'
    ];

    final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Patient Profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),

                    const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(hintText: 'Full Name'),
                    ),
                    const SizedBox(height: 12),

                    const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'Phone Number'),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedGender,
                                items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                onChanged: (v) => setSheetState(() => selectedGender = v!),
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
                                initialValue: selectedCivilStatus,
                                items: ['Single', 'Married', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                onChanged: (v) => setSheetState(() => selectedCivilStatus = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text('Address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Address'),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('District', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedDistrict,
                                items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                                onChanged: (v) => setSheetState(() => selectedDistrict = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Blood Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedBloodGroup,
                                items: bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                                onChanged: (v) => setSheetState(() => selectedBloodGroup = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text('Emergency Contact Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emergencyNameController,
                      decoration: const InputDecoration(hintText: 'Emergency Contact Name'),
                    ),
                    const SizedBox(height: 12),

                    const Text('Emergency Contact Phone', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emergencyPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: 'Emergency Contact Phone'),
                    ),
                    const SizedBox(height: 12),

                    const Text('Allergies', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: allergiesController,
                      decoration: const InputDecoration(hintText: 'Drug / Food Allergies'),
                    ),
                    const SizedBox(height: 12),

                    const Text('Pre-existing Medical Conditions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: medicalConditionsController,
                      maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Medical Conditions'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          setState(() => _isLoading = true);

                          final res = await AuthService.updateProfile(
                            fullName: fullNameController.text,
                            phone: phoneController.text,
                            gender: selectedGender,
                            dateOfBirth: user['date_of_birth'] ?? '',
                            civilStatus: selectedCivilStatus,
                            address: addressController.text,
                            district: selectedDistrict,
                            emergencyContactName: emergencyNameController.text,
                            emergencyContactPhone: emergencyPhoneController.text,
                            bloodGroup: selectedBloodGroup,
                            allergies: allergiesController.text,
                            medicalConditions: medicalConditionsController.text,
                          );

                          if (mounted) {
                            setState(() => _isLoading = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(res['message'] ?? 'Profile updated'),
                                backgroundColor: res['success'] == true ? AppTheme.primaryTeal : AppTheme.errorRed,
                              ),
                            );
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 28),
              SizedBox(width: 10),
              Text('Delete Account?'),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete your MediQ patient profile? This action cannot be undone.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                navigator.pop();
                setState(() => _isLoading = true);

                final res = await AuthService.deleteAccount();

                if (mounted) {
                  setState(() => _isLoading = false);
                  if (res['success'] == true) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Your account has been deleted.'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Failed to delete account'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Patient Name';
    final nic = user['nic'] ?? 'N/A';
    final phone = user['phone'] ?? 'N/A';
    final dob = user['date_of_birth'] ?? 'N/A';
    final gender = user['gender'] ?? 'N/A';
    final civilStatus = user['civil_status'] ?? 'N/A';
    final address = user['address'] ?? 'N/A';
    final district = user['district'] ?? 'N/A';
    final emergencyName = user['emergency_contact_name'] ?? 'N/A';
    final emergencyPhone = user['emergency_contact_phone'] ?? 'N/A';
    final bloodGroup = user['blood_group'] ?? 'N/A';
    final allergies = user['allergies'] ?? 'None';
    final medicalConditions = user['medical_conditions'] ?? 'None';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryTeal.withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fullName,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'NIC: $nic',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section 1: Personal Details
                  _buildSectionCard(
                    title: 'Personal Information',
                    icon: Icons.person_outline_rounded,
                    items: [
                      _buildInfoRow('Full Name', fullName),
                      _buildInfoRow('NIC Number', nic),
                      _buildInfoRow('Date of Birth', dob),
                      _buildInfoRow('Gender', gender),
                      _buildInfoRow('Civil Status', civilStatus),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 2: Contact Details
                  _buildSectionCard(
                    title: 'Contact & Location',
                    icon: Icons.contact_mail_outlined,
                    items: [
                      _buildInfoRow('Phone Number', phone),
                      _buildInfoRow('Address', address),
                      _buildInfoRow('District', district),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 3: Emergency Contact
                  _buildSectionCard(
                    title: 'Emergency Contact',
                    icon: Icons.phone_in_talk_outlined,
                    items: [
                      _buildInfoRow('Contact Person', emergencyName),
                      _buildInfoRow('Emergency Phone', emergencyPhone),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 4: Medical Background
                  _buildSectionCard(
                    title: 'Medical Background',
                    icon: Icons.medical_information_outlined,
                    items: [
                      _buildInfoRow('Blood Group', bloodGroup),
                      _buildInfoRow('Allergies', allergies),
                      _buildInfoRow('Pre-existing Conditions', medicalConditions),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Action Buttons: Edit & Delete
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showEditProfileSheet,
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: const Text('Edit Profile'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
                            foregroundColor: AppTheme.errorRed,
                          ),
                          onPressed: _showDeleteAccountDialog,
                          icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.errorRed, size: 18),
                          label: const Text('Delete Profile', style: TextStyle(color: AppTheme.errorRed)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryTeal, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedText, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppTheme.darkText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
