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
        'isTakenToday': true,
      },
      {
        'id': '2',
        'name': 'Omeprazole 20mg',
        'dosage': '1 Capsule',
        'schedule': ['Morning'],
        'instructions': 'Before breakfast with water',
        'isTakenToday': false,
      },
      {
        'id': '3',
        'name': 'Multivitamin',
        'dosage': '1 Tablet',
        'schedule': ['Morning'],
        'instructions': 'After meal',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medication_rounded, color: Color(0xFF8B5CF6)),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add New Medication',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Medicine Name',
                      hintText: 'e.g., Amoxicillin 500mg',
                      prefixIcon: Icon(Icons.medical_information_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'e.g., 1 Tablet / 5ml',
                      prefixIcon: Icon(Icons.numbers_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instructionsController,
                    decoration: const InputDecoration(
                      labelText: 'Instructions (Optional)',
                      hintText: 'e.g., After meals with warm water',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Daily Schedule:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilterChip(
                        avatar: const Icon(Icons.wb_twilight, size: 16),
                        label: const Text('Morning'),
                        selected: morning,
                        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        onSelected: (val) => setModalState(() => morning = val),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.wb_sunny, size: 16),
                        label: const Text('Afternoon'),
                        selected: afternoon,
                        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        onSelected: (val) => setModalState(() => afternoon = val),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        avatar: const Icon(Icons.nightlight_round, size: 16),
                        label: const Text('Night'),
                        selected: night,
                        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        onSelected: (val) => setModalState(() => night = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        if (nameController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please enter medicine name')),
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
                          'isTakenToday': false,
                        };

                        setState(() {
                          _medicines.add(newPill);
                        });
                        _saveMedicines();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save Medication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 16,
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
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Today\'s Medication Goal',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '$takenCount of $totalPills Doses Taken',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Medicines Checklist',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF8B5CF6)),
                        label: const Text('Add Pill', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.medication_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'No Medication Added Yet',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap "+ Add Pill" to track your daily prescribed doses.',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedText),
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

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isTaken ? const Color(0xFF10B981).withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isTaken ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.grey.shade200,
                              width: isTaken ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
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
                                    color: isTaken ? const Color(0xFF10B981) : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isTaken ? const Color(0xFF10B981) : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    isTaken ? Icons.check_rounded : Icons.circle_outlined,
                                    color: isTaken ? Colors.white : Colors.grey.shade400,
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
                                        color: AppTheme.darkText,
                                        decoration: isTaken ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dosage: ${item['dosage']}  |  ${item['instructions']}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      children: sched.map((s) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            s.toString(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF8B5CF6),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade400, size: 20),
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
