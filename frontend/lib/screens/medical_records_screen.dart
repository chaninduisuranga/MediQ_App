import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/medical_record_service.dart';
import '../core/theme/theme.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  List<dynamic> _doctorRecords = [];
  List<dynamic> _prescriptionPhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchRecords();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);

    final res = await MedicalRecordService.getPatientRecords();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          final all = res['data'] as List<dynamic>;
          _doctorRecords = all.where((r) => r['record_type'] == 'DOCTOR_DIAGNOSIS').toList();
          _prescriptionPhotos = all.where((r) => r['record_type'] == 'PATIENT_UPLOAD' || r['image_url'] != null).toList();
        }
      });
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedFile == null) return;

      final titleController = TextEditingController(text: 'Prescription ${DateTime.now().day}/${DateTime.now().month}');
      final notesController = TextEditingController();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt_rounded, color: AppTheme.primaryTeal),
                SizedBox(width: 10),
                Text('Prescription Details'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title / Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(hintText: 'e.g. ENT Clinic Prescription'),
                  ),
                  const SizedBox(height: 14),

                  const Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'e.g. 5-day antibiotic course'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  navigator.pop(); // Close details dialog

                  // Show upload progress modal
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingCtx) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            CircularProgressIndicator(color: AppTheme.primaryTeal, strokeWidth: 3),
                            SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                'Uploading prescription photo...',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  Map<String, dynamic> res;
                  if (kIsWeb) {
                    final bytes = await pickedFile.readAsBytes();
                    res = await MedicalRecordService.uploadPrescription(
                      title: titleController.text,
                      notes: notesController.text,
                      fileBytes: bytes,
                      fileName: pickedFile.name,
                    );
                  } else {
                    res = await MedicalRecordService.uploadPrescription(
                      title: titleController.text,
                      notes: notesController.text,
                      filePath: pickedFile.path,
                    );
                  }

                  if (mounted) {
                    navigator.pop(); // Close progress dialog

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? '✅ Prescription uploaded successfully!'),
                        backgroundColor: res['success'] == true ? AppTheme.primaryTeal : AppTheme.errorRed,
                      ),
                    );

                    await _fetchRecords();
                    _tabController.animateTo(1); // Switch to My Prescriptions tab immediately
                  }
                },
                child: const Text('Upload Photo'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to access camera/gallery'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Prescription Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.primaryTeal.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryTeal),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryBlue),
                  ),
                  title: const Text('Select from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showZoomImageModal(String imageUrl, String title, String date) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    _resolveImageUrl(imageUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, color: Colors.white70, size: 60),
                          SizedBox(height: 10),
                          Text('Image preview not available', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteRecord(int id) async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await MedicalRecordService.deleteRecord(id);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Record deleted'),
          backgroundColor: res['success'] == true ? AppTheme.primaryTeal : AppTheme.errorRed,
        ),
      );
      _fetchRecords();
    }
  }

  String _resolveImageUrl(String path) => MedicalRecordService.resolveImageUrl(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Records & History'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.mutedText,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.medical_information_rounded), text: 'Doctor History'),
            Tab(icon: Icon(Icons.photo_library_rounded), text: 'My Prescriptions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDoctorHistoryTab(),
          _buildPrescriptionPhotosTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showImageSourcePicker,
              backgroundColor: AppTheme.primaryTeal,
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              label: const Text('Upload Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // TAB 1: Doctor Diagnoses & History
  Widget _buildDoctorHistoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: AppTheme.primaryTeal, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Official OPD Doctor Consultations & Diagnoses are automatically recorded here.',
                      style: TextStyle(fontSize: 13, color: AppTheme.darkText, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: AppTheme.primaryTeal)))
            else if (_doctorRecords.isEmpty)
              _buildEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No Doctor Records Yet',
                subtitle: 'Your medical diagnoses and prescriptions from OPD visits will be displayed here.',
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _doctorRecords.length,
                itemBuilder: (context, index) {
                  final rec = _doctorRecords[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rec['title'] ?? 'OPD Consultation',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                              ),
                              Text(
                                rec['record_date'] != null ? rec['record_date'].toString().split('T')[0] : '',
                                style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Doctor: ${rec['doctor_name'] ?? 'OPD Doctor'}', style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Clinic: ${rec['clinic_name'] ?? 'General OPD'}', style: const TextStyle(color: AppTheme.mutedText, fontSize: 12)),
                          if (rec['diagnosis'] != null && rec['diagnosis'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(),
                            Text('Diagnosis: ${rec['diagnosis']}', style: const TextStyle(fontSize: 13, color: AppTheme.darkText)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // TAB 2: Patient Uploaded Prescription Photos
  Widget _buildPrescriptionPhotosTab() {
    return RefreshIndicator(
      onRefresh: _fetchRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Banner Action Card
            GestureDetector(
              onTap: _showImageSourcePicker,
              child: Container(
                padding: const EdgeInsets.all(18),
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
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Prescription Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                          SizedBox(height: 2),
                          Text('Take a camera photo of your medicine slip or lab report', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Saved Prescriptions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
            const SizedBox(height: 14),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: AppTheme.primaryTeal)))
            else if (_prescriptionPhotos.isEmpty)
              _buildEmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No Prescriptions Uploaded',
                subtitle: 'Tap the button above or camera icon to capture and save your prescription photos.',
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.8,
                ),
                itemCount: _prescriptionPhotos.length,
                itemBuilder: (context, index) {
                  final item = _prescriptionPhotos[index];
                  final imageUrl = item['image_url'] ?? '';
                  final title = item['title'] ?? 'Prescription';
                  final date = item['record_date'] != null ? item['record_date'].toString().split('T')[0] : '';
                  final id = item['id'];

                  return GestureDetector(
                    onTap: () => _showZoomImageModal(imageUrl, title, date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.network(
                                      _resolveImageUrl(imageUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.teal.shade50,
                                        child: const Center(
                                          child: Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.primaryTeal),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(6),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Prescription?'),
                                              content: const Text('Are you sure you want to delete this prescription photo?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    _deleteRecord(id);
                                                  },
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: AppTheme.mutedText.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppTheme.mutedText)),
        ],
      ),
    );
  }
}
