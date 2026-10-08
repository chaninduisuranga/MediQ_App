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

  // OPD Doctor History (from completed appointments)
  List<dynamic> _doctorHistory = [];
  List<String> _availableMonths = [];  // e.g. ["2026-10", "2026-09"]
  String? _selectedMonth;              // null = All
  bool _isLoadingHistory = true;

  // Prescription photos
  List<dynamic> _prescriptionPhotos = [];
  bool _isLoadingPhotos = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchDoctorHistory();
    _fetchPrescriptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctorHistory({String? month}) async {
    setState(() => _isLoadingHistory = true);
    final res = await MedicalRecordService.getDoctorHistory(month: month);
    if (mounted) {
      setState(() {
        _isLoadingHistory = false;
        if (res['success'] == true) {
          _doctorHistory = (res['data'] as List<dynamic>? ?? []);
          // Build unique month list from all history (for filter chips)
          // Re-fetch all months when no month filter active
          if (month == null) {
            final months = <String>{};
            for (final item in _doctorHistory) {
              final date = item['appointment_date'] as String? ?? '';
              if (date.length >= 7) months.add(date.substring(0, 7)); // YYYY-MM
            }
            final sortedMonths = months.toList()..sort((a, b) => b.compareTo(a));
            _availableMonths = sortedMonths;
          }
        }
      });
    }
  }

  Future<void> _fetchPrescriptions() async {
    setState(() => _isLoadingPhotos = true);
    final res = await MedicalRecordService.getPatientRecords();
    if (mounted) {
      setState(() {
        _isLoadingPhotos = false;
        if (res['success'] == true) {
          final all = res['data'] as List<dynamic>;
          _prescriptionPhotos = all
              .where((r) => r['record_type'] == 'PATIENT_UPLOAD' || r['image_url'] != null)
              .toList();
        }
      });
    }
  }

  Future<void> _fetchRecords() async {
    await Future.wait([_fetchDoctorHistory(month: _selectedMonth), _fetchPrescriptions()]);
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

  // ─── HELPER: Room display name → icon + accent color ─────────────────────
  IconData _roomIcon(String roomKey) {
    switch (roomKey) {
      case 'DRESSING_ROOM':    return Icons.healing_rounded;
      case 'INJECTION_ROOM':   return Icons.vaccines_rounded;
      case 'BLEEDING_ROOM':    return Icons.bloodtype_rounded;
      case 'ANIMAL_BITE_ROOM': return Icons.pets_rounded;
      case 'OPD_CLINIC_ROOM':  return Icons.local_hospital_rounded;
      case 'DISPENSARY_ROOM':  return Icons.medication_rounded;
      default:                 return Icons.medical_services_rounded;
    }
  }

  Color _roomColor(String roomKey) {
    switch (roomKey) {
      case 'DRESSING_ROOM':    return const Color(0xFF6366F1);
      case 'INJECTION_ROOM':   return const Color(0xFF10B981);
      case 'BLEEDING_ROOM':    return const Color(0xFFEF4444);
      case 'ANIMAL_BITE_ROOM': return const Color(0xFFF59E0B);
      case 'OPD_CLINIC_ROOM':  return const Color(0xFF2563EB);
      case 'DISPENSARY_ROOM':  return const Color(0xFF8B5CF6);
      default:                 return const Color(0xFF64748B);
    }
  }

  // Converts "YYYY-MM" → "October 2026"
  String _formatMonthLabel(String ym) {
    final parts = ym.split('-');
    if (parts.length < 2) return ym;
    final year = parts[0];
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    final mNum = int.tryParse(parts[1]) ?? 0;
    return '${months[mNum]} $year';
  }

  // ─── TAB 1: OPD Doctor History ────────────────────────────────────────────
  Widget _buildDoctorHistoryTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchDoctorHistory(month: _selectedMonth),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Info Banner ──────────────────────────────────────────────────
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
                    child: const Icon(Icons.history_edu_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OPD Consultation History',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'All completed OPD visits are automatically recorded here with doctor notes.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Month Filter Chips ───────────────────────────────────────────
            if (_availableMonths.isNotEmpty) ...[
              const Text('Filter by Month',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "All" chip
                    _buildMonthChip(null),
                    const SizedBox(width: 8),
                    ..._availableMonths
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildMonthChip(m),
                            ))
                        ,
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Content ───────────────────────────────────────────────────
            if (_isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                ),
              )
            else if (_doctorHistory.isEmpty)
              _buildEmptyState(
                icon: Icons.history_edu_outlined,
                title: 'No Consultation History',
                subtitle: _selectedMonth != null
                    ? 'No completed OPD visits for ${_formatMonthLabel(_selectedMonth!)}.'
                    : 'Your OPD consultation records will appear here after a completed visit.',
              )
            else ...[
              Row(
                children: [
                  Text('${_doctorHistory.length} consultation(s)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  if (_selectedMonth != null) ...[
                    const SizedBox(width: 6),
                    Text('· ${_formatMonthLabel(_selectedMonth!)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ..._doctorHistory.map((item) => _buildConsultationCard(item)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthChip(String? month) {
    final isSelected = _selectedMonth == month;
    final label = month == null ? 'All' : _formatMonthLabel(month);
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMonth = month);
        _fetchDoctorHistory(month: month);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)])
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> item) {
    final date          = item['appointment_date'] as String? ?? '';
    final time          = item['appointment_time'] as String? ?? '';
    final roomKey       = item['room'] as String? ?? '';
    final roomName      = item['room_display_name'] as String? ?? roomKey;
    final doctorName    = item['doctor_name'] as String? ?? 'OPD Doctor';
    final notes         = item['notes'] as String? ?? '';
    final queueNum      = item['queue_number'] as int? ?? 0;
    final completedAt   = item['completed_at'] as String? ?? '';
    final accent        = _roomColor(roomKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          // ── Header strip ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0F172A), accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_roomIcon(roomKey), color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roomName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('$date${time.isNotEmpty ? ' · $time' : ''}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Q#$queueNum',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.person_rounded, size: 16, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Attending Doctor',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                          Text(doctorName,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent)),
                        ],
                      ),
                    ),
                    if (completedAt.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text('Completed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                  ],
                ),

                // Doctor notes (if any)
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_alt_rounded, size: 14, color: accent),
                            const SizedBox(width: 6),
                            Text('Doctor\'s Notes',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notes,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF94A3B8)),
                        SizedBox(width: 6),
                        Text('No consultation notes recorded for this visit.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],

                // Completed time footer
                if (completedAt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text('Consultation completed: $completedAt',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
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

            if (_isLoadingPhotos)
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
