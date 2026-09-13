import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/medical_record_service.dart';
import '../core/theme/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text('Prescription Details', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Title / Description', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g. ENT Clinic Prescription',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. 5-day antibiotic course',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  navigator.pop();

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingCtx) => Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Row(
                          children: [
                            CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3),
                            SizedBox(width: 20),
                            Expanded(
                              child: Text(
                                'Uploading prescription photo...',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
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
                    navigator.pop();

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? '✅ Prescription uploaded successfully!'),
                        backgroundColor: res['success'] == true ? const Color(0xFF2563EB) : AppTheme.errorRed,
                      ),
                    );

                    await _fetchRecords();
                    _tabController.animateTo(1);
                  }
                },
                child: const Text('Upload Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Add Prescription Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
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
                    decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0EA5E9)),
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
          backgroundColor: res['success'] == true ? const Color(0xFF2563EB) : AppTheme.errorRed,
        ),
      );
      _fetchRecords();
    }
  }

  String _resolveImageUrl(String path) => MedicalRecordService.resolveImageUrl(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Medical Records & History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
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
          ? Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: FloatingActionButton.extended(
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: _showImageSourcePicker,
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                label: const Text('Upload Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          : null,
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
    );
  }

  // TAB 1: Doctor Diagnoses & History
  Widget _buildDoctorHistoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ultra-Modern Info Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Official OPD Medical Record', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Doctor consultations, diagnoses & official prescriptions are automatically stored here.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Color(0xFF2563EB))))
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF3B82F6)]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rec['title'] ?? 'OPD Consultation',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      rec['record_date'] != null ? rec['record_date'].toString().split('T')[0] : '',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text('Doctor: ${rec['doctor_name'] ?? 'OPD Doctor'}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_hospital_outlined, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 6),
                              Text('Clinic: ${rec['clinic_name'] ?? 'General OPD'}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                          if (rec['diagnosis'] != null && rec['diagnosis'].toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                'Diagnosis: ${rec['diagnosis']}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                              ),
                            ),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Banner Action Card
            GestureDetector(
              onTap: _showImageSourcePicker,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Prescription Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          SizedBox(height: 2),
                          Text('Take a photo of your medicine slip or lab report', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),
            const Text('Saved Prescriptions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 14),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: Color(0xFF2563EB))))
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
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
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
                                        color: const Color(0xFFEFF6FF),
                                        child: const Center(
                                          child: Icon(Icons.receipt_long_rounded, size: 44, color: Color(0xFF2563EB)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
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
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              title: const Text('Delete Prescription?', style: TextStyle(fontWeight: FontWeight.bold)),
                                              content: const Text('Are you sure you want to delete this prescription photo?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    _deleteRecord(id);
                                                  },
                                                  child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    date,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: const Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
