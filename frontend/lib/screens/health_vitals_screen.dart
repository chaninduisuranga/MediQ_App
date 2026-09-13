import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthVitalsScreen extends StatefulWidget {
  const HealthVitalsScreen({super.key});

  @override
  State<HealthVitalsScreen> createState() => _HealthVitalsScreenState();
}

class _HealthVitalsScreenState extends State<HealthVitalsScreen> {
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '68');

  final _sysBpController = TextEditingController();
  final _diaBpController = TextEditingController();
  final _sugarController = TextEditingController();

  double _bmi = 23.53;
  String _bmiCategory = 'Normal';
  Color _bmiColor = const Color(0xFF10B981);
  String _targetWeightRange = '53.5 kg - 72.2 kg';

  List<Map<String, dynamic>> _vitalsLog = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateBMI();
    _loadVitalsLog();
  }

  void _calculateBMI() {
    double heightCm = double.tryParse(_heightController.text) ?? 170;
    double weightKg = double.tryParse(_weightController.text) ?? 68;

    if (heightCm <= 0 || weightKg <= 0) return;

    double heightM = heightCm / 100;
    double bmiVal = weightKg / (heightM * heightM);

    String cat;
    Color color;

    if (bmiVal < 18.5) {
      cat = 'Underweight';
      color = const Color(0xFF0EA5E9);
    } else if (bmiVal < 25.0) {
      cat = 'Normal Weight';
      color = const Color(0xFF10B981);
    } else if (bmiVal < 30.0) {
      cat = 'Overweight';
      color = const Color(0xFFF59E0B);
    } else {
      cat = 'Obese';
      color = const Color(0xFFEF4444);
    }

    double minWeight = 18.5 * heightM * heightM;
    double maxWeight = 24.9 * heightM * heightM;

    setState(() {
      _bmi = bmiVal;
      _bmiCategory = cat;
      _bmiColor = color;
      _targetWeightRange = '${minWeight.toStringAsFixed(1)} kg - ${maxWeight.toStringAsFixed(1)} kg';
    });
  }

  Future<void> _loadVitalsLog() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataStr = prefs.getString('mediq_vitals_log');
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(dataStr);
        setState(() {
          _vitalsLog = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
        return;
      } catch (e) {
        // Fallback
      }
    }

    // Default sample records
    _vitalsLog = [
      {
        'date': 'Today',
        'bp': '120/80 mmHg',
        'sugar': '95 mg/dL',
        'weight': '68 kg',
      },
    ];
    await _saveVitalsLog();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveVitalsLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mediq_vitals_log', jsonEncode(_vitalsLog));
  }

  void _addVitalsLogEntry() {
    String sys = _sysBpController.text.trim();
    String dia = _diaBpController.text.trim();
    String sugar = _sugarController.text.trim();

    if (sys.isEmpty && sugar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Blood Pressure or Sugar reading')),
      );
      return;
    }

    String bpText = (sys.isNotEmpty && dia.isNotEmpty) ? '$sys/$dia mmHg' : (sys.isNotEmpty ? '$sys mmHg' : 'N/A');
    String sugarText = sugar.isNotEmpty ? '$sugar mg/dL' : 'N/A';
    String weightText = '${_weightController.text} kg';

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final newEntry = {
      'date': dateStr,
      'bp': bpText,
      'sugar': sugarText,
      'weight': weightText,
    };

    setState(() {
      _vitalsLog.insert(0, newEntry);
    });
    _saveVitalsLog();

    _sysBpController.clear();
    _diaBpController.clear();
    _sugarController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Health reading logged successfully!'), backgroundColor: Color(0xFF2563EB)),
    );
  }

  void _deleteVitalsEntry(int index) {
    setState(() {
      _vitalsLog.removeAt(index);
    });
    _saveVitalsLog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Health Vitals & BMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3D Glassmorphic BMI Calculator Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFF43F5E)]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.monitor_weight_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('BMI Calculator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text('Body Mass Index & Ideal Weight', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _heightController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Height (cm)',
                                  prefixIcon: const Icon(Icons.height_rounded, color: Color(0xFF2563EB)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                onChanged: (_) => _calculateBMI(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _weightController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Weight (kg)',
                                  prefixIcon: const Icon(Icons.scale_rounded, color: Color(0xFF2563EB)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                onChanged: (_) => _calculateBMI(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // BMI Result Display
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _bmiColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _bmiColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('YOUR BMI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                  Text(
                                    _bmi.toStringAsFixed(1),
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _bmiColor),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _bmiColor,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(color: _bmiColor.withValues(alpha: 0.3), blurRadius: 6),
                                      ],
                                    ),
                                    child: Text(
                                      _bmiCategory,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ideal: $_targetWeightRange',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),
                  const Text(
                    'Log Daily Vitals',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  // Vitals Logger Form Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _sysBpController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Systolic BP',
                                  hintText: '120',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _diaBpController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Diastolic BP',
                                  hintText: '80',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _sugarController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Fasting Blood Sugar (mg/dL)',
                            hintText: 'e.g., 95',
                            prefixIcon: const Icon(Icons.water_drop_rounded, color: Color(0xFFEF4444)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.bookmark_add_rounded, color: Colors.white, size: 20),
                              label: const Text('Save Vitals Log', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              onPressed: _addVitalsLogEntry,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const Text(
                    'Vitals History Log',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _vitalsLog.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _vitalsLog[index];

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite_rounded, color: Color(0xFF2563EB), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BP: ${item['bp']}  |  Sugar: ${item['sugar']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Weight: ${item['weight']}  •  Logged: ${item['date']}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () => _deleteVitalsEntry(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
