import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/theme.dart';

class PillTrackerScreen extends StatefulWidget {
  const PillTrackerScreen({super.key});

  @override
  State<PillTrackerScreen> createState() => _PillTrackerScreenState();
}

class _PillTrackerScreenState extends State<PillTrackerScreen> {
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataStr = prefs.getString('mediq_pill_list');
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(dataStr);
        setState(() {
          _medicines = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
        return;
      } catch (e) {
        // Fallback to initial default sample data if corrupt
      }
    }

    // Default sample pills for first time user
    _medicines = [
      {
        'id': '1',
        'name': 'Paracetamol 500mg',
        'dosage': '1 Tablet',
        'schedule': ['Morning', 'Night'],
        'instructions': 'After meals',
        'duration': '5 Days',
        'frequencyPattern': 'Everyday',
        'isTakenToday': true,
      },
      {
        'id': '2',
        'name': 'Omeprazole 20mg',
        'dosage': '1 Capsule',
        'schedule': ['Morning'],
        'instructions': 'Before breakfast with water',
        'duration': '14 Days',
        'frequencyPattern': 'Every 2nd Day',
        'isTakenToday': false,
      },
      {
        'id': '3',
        'name': 'Multivitamin',
        'dosage': '1 Tablet',
        'schedule': ['Morning'],
        'instructions': 'After meal',
        'duration': 'Continuous',
        'frequencyPattern': 'Everyday',
        'isTakenToday': false,
      },
    ];
    await _saveMedicines();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mediq_pill_list', jsonEncode(_medicines));
  }

  void _toggleTakenStatus(int index) {
    setState(() {
      _medicines[index]['isTakenToday'] = !(_medicines[index]['isTakenToday'] ?? false);
    });
    _saveMedicines();
  }

  void _deleteMedicine(int index) {
    final deleted = _medicines[index]['name'];
    setState(() {
      _medicines.removeAt(index);
    });
    _saveMedicines();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deleted removed'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddMedicineModal() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final instructionsController = TextEditingController();
    bool morning = true;
    bool afternoon = false;
    bool night = false;

    String selectedDuration = '7 Days';
    String selectedFrequency = 'Everyday';

    final durationOptions = ['5 Days', '7 Days', '14 Days', '30 Days', 'Continuous'];
    final frequencyOptions = ['Everyday', 'Every 2nd Day', 'Every 3rd Day', 'Weekly'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle Bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.medication_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Medication',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Set dose schedule & course duration',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, thickness: 0.8),

                  // Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 22,
                        right: 22,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Input: Medicine Name
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Medicine Name',
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              hintText: 'e.g., Amoxicillin 500mg',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.medical_information_outlined, color: Color(0xFF2563EB)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Input: Dosage
                          TextField(
                            controller: dosageController,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Dosage',
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              hintText: 'e.g., 1 Tablet / 5ml',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.numbers_outlined, color: Color(0xFF2563EB)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Input: Instructions
                          TextField(
                            controller: instructionsController,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Instructions (Optional)',
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              hintText: 'e.g., After meals with warm water',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              prefixIcon: const Icon(Icons.notes_outlined, color: Color(0xFF2563EB)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Daily Time Schedule Section
                          const Text(
                            'Daily Time Schedule:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildScheduleChip(
                                label: 'Morning',
                                icon: Icons.wb_twilight_rounded,
                                isSelected: morning,
                                onTap: (val) => setModalState(() => morning = val),
                              ),
                              const SizedBox(width: 8),
                              _buildScheduleChip(
                                label: 'Afternoon',
                                icon: Icons.wb_sunny_rounded,
                                isSelected: afternoon,
                                onTap: (val) => setModalState(() => afternoon = val),
                              ),
                              const SizedBox(width: 8),
                              _buildScheduleChip(
                                label: 'Night',
                                icon: Icons.nightlight_round,
                                isSelected: night,
                                onTap: (val) => setModalState(() => night = val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Course Duration Section (කොච්චර දවස්ද)
                          const Text(
                            'Course Duration (දින ගණන):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: durationOptions.map((dur) {
                              final isSel = selectedDuration == dur;
                              return ChoiceChip(
                                avatar: Icon(
                                  Icons.timer_outlined,
                                  size: 15,
                                  color: isSel ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                ),
                                label: Text(
                                  dur,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFFFEF3C7),
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: BorderSide(
                                  color: isSel ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                  width: isSel ? 1.5 : 1,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) {
                                  if (val) setModalState(() => selectedDuration = dur);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),

                          // Frequency Interval Section (දවස් අර දවස්ද)
                          const Text(
                            'Repeat Frequency (දින පරතරය):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: frequencyOptions.map((freq) {
                              final isSel = selectedFrequency == freq;
                              return ChoiceChip(
                                avatar: Icon(
                                  Icons.repeat_rounded,
                                  size: 15,
                                  color: isSel ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                ),
                                label: Text(
                                  freq,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                    color: isSel ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                                  ),
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFFF3E8FF),
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: BorderSide(
                                  color: isSel ? const Color(0xFF8B5CF6) : const Color(0xFFE2E8F0),
                                  width: isSel ? 1.5 : 1,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (val) {
                                  if (val) setModalState(() => selectedFrequency = freq);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 26),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () {
                                  if (nameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter medicine name'),
                                        backgroundColor: AppTheme.errorRed,
                                      ),
                                    );
                                    return;
                                  }
                                  List<String> sched = [];
                                  if (morning) sched.add('Morning');
                                  if (afternoon) sched.add('Afternoon');
                                  if (night) sched.add('Night');
                                  if (sched.isEmpty) sched.add('Daily');

                                  final newPill = {
                                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                    'name': nameController.text.trim(),
                                    'dosage': dosageController.text.trim().isEmpty ? '1 Dose' : dosageController.text.trim(),
                                    'schedule': sched,
                                    'instructions': instructionsController.text.trim().isEmpty ? 'As prescribed' : instructionsController.text.trim(),
                                    'duration': selectedDuration,
                                    'frequencyPattern': selectedFrequency,
                                    'isTakenToday': false,
                                  };

                                  setState(() {
                                    _medicines.add(newPill);
                                  });
                                  _saveMedicines();
                                  Navigator.pop(ctx);
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save Medication',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool> onTap,
  }) {
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPills = _medicines.length;
    int takenCount = _medicines.where((m) => m['isTakenToday'] == true).length;
    double progress = totalPills == 0 ? 0.0 : (takenCount / totalPills);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pill & Dose Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              onPressed: _showAddMedicineModal,
              tooltip: 'Add Medicine',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Banner Card (MediQ Royal Blue Modern Gradient)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alarm_on_rounded, color: Color(0xFF38BDF8), size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Today\'s Medication Goal',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$takenCount of $totalPills Doses Taken',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Medicines Checklist',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
                        label: const Text('Add Pill', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: _showAddMedicineModal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_medicines.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.medication_outlined, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'No Medication Added Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap "+ Add Pill" to track your daily prescribed doses.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _medicines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _medicines[index];
                        final isTaken = item['isTakenToday'] ?? false;
                        final List<dynamic> sched = item['schedule'] ?? [];
                        final durationStr = item['duration'] as String? ?? 'Continuous';
                        final freqStr = item['frequencyPattern'] as String? ?? 'Everyday';

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isTaken ? const Color(0xFF10B981).withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isTaken ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                              width: isTaken ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isTaken ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleTakenStatus(index),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isTaken ? const Color(0xFF10B981) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isTaken ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    isTaken ? Icons.check_rounded : Icons.circle_outlined,
                                    color: isTaken ? Colors.white : const Color(0xFF94A3B8),
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                        decoration: isTaken ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Dosage: ${item['dosage']}  |  ${item['instructions']}',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),

                                    // Schedule & Duration & Pattern Badges
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        // Daily time chips
                                        ...sched.map((s) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFBFDBFE)),
                                            ),
                                            child: Text(
                                              s.toString(),
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          );
                                        }),

                                        // Duration badge ( amber )
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.timer_outlined, size: 11, color: Color(0xFFD97706)),
                                              const SizedBox(width: 3),
                                              Text(
                                                durationStr,
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFD97706),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Repeat frequency pattern badge ( purple )
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF3E8FF),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE9D5FF)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.repeat_rounded, size: 11, color: Color(0xFF7C3AED)),
                                              const SizedBox(width: 3),
                                              Text(
                                                freqStr,
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                                onPressed: () => _deleteMedicine(index),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
