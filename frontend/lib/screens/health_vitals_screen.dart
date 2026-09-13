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
  String _bmiCategory = 'Normal Weight';
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

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _sysBpController.dispose();
    _diaBpController.dispose();
    _sugarController.dispose();
    super.dispose();
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
        // Fallback if parse fails
      }
    }

    // Default sample records
    _vitalsLog = [
      {
        'date': 'Today, 08:30 AM',
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Please enter Blood Pressure or Blood Sugar reading'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    String bpText = (sys.isNotEmpty && dia.isNotEmpty) ? '$sys/$dia mmHg' : (sys.isNotEmpty ? '$sys mmHg' : 'N/A');
    String sugarText = sugar.isNotEmpty ? '$sugar mg/dL' : 'N/A';
    String weightText = '${_weightController.text} kg';

    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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

    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Health reading logged successfully!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _deleteVitalsEntry(int index) {
    setState(() {
      _vitalsLog.removeAt(index);
    });
    _saveVitalsLog();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Log entry removed'),
        backgroundColor: const Color(0xFF64748B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // Position ratio for the BMI Meter gauge (Range 15.0 to 35.0)
  double _getBmiGaugeRatio() {
    double clamped = _bmi.clamp(15.0, 35.0);
    return (clamped - 15.0) / (35.0 - 15.0);
  }

  @override
  Widget build(BuildContext context) {
    final String lastBp = _vitalsLog.isNotEmpty ? _vitalsLog.first['bp'] ?? 'N/A' : 'N/A';
    final String lastSugar = _vitalsLog.isNotEmpty ? _vitalsLog.first['sugar'] ?? 'N/A' : 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Health Vitals & BMI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
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
          IconButton(
            icon: const Icon(Icons.favorite_rounded, color: Color(0xFFEC4899), size: 22),
            onPressed: () {},
            tooltip: 'Health Metrics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header with Gradient & Quick Vitals Overview
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF38BDF8), size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Personal Health Dashboard',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Track BMI, Blood Pressure & Glucose',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 3 Summary Cards Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildHeaderStatCard(
                                title: 'BMI Index',
                                value: _bmi.toStringAsFixed(1),
                                badgeText: _bmiCategory,
                                badgeColor: _bmiColor,
                                icon: Icons.speed_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildHeaderStatCard(
                                title: 'Latest BP',
                                value: lastBp.split(' ').first,
                                badgeText: 'mmHg',
                                badgeColor: const Color(0xFF38BDF8),
                                icon: Icons.favorite_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildHeaderStatCard(
                                title: 'Blood Sugar',
                                value: lastSugar.split(' ').first,
                                badgeText: 'mg/dL',
                                badgeColor: const Color(0xFFF43F5E),
                                icon: Icons.water_drop_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: BMI Calculator & Visual Spectrum Gauge
                        _buildSectionHeader(
                          title: 'BMI Calculator & Spectrum',
                          subtitle: 'Enter your height & weight to measure body index',
                          icon: Icons.scale_rounded,
                          iconColor: const Color(0xFF2563EB),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _heightController,
                                      label: 'Height (cm)',
                                      hint: '170',
                                      icon: Icons.height_rounded,
                                      iconColor: const Color(0xFF2563EB),
                                      onChanged: (_) => _calculateBMI(),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _weightController,
                                      label: 'Weight (kg)',
                                      hint: '68',
                                      icon: Icons.monitor_weight_outlined,
                                      iconColor: const Color(0xFFEC4899),
                                      onChanged: (_) => _calculateBMI(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Dynamic BMI Score Display Container
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _bmiColor.withValues(alpha: 0.1),
                                      _bmiColor.withValues(alpha: 0.03),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: _bmiColor.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'YOUR BMI SCORE',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF64748B),
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  _bmi.toStringAsFixed(1),
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w900,
                                                    color: _bmiColor,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'kg/m²',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: _bmiColor,
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: _bmiColor.withValues(alpha: 0.35),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                _bmiCategory,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Ideal: $_targetWeightRange',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),

                                    // Visual BMI Spectrum Gauge Bar
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Marker Pointer
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            double markerPos = constraints.maxWidth * _getBmiGaugeRatio();
                                            markerPos = markerPos.clamp(10.0, constraints.maxWidth - 20.0);
                                            return Stack(
                                              children: [
                                                SizedBox(
                                                  height: 18,
                                                  width: constraints.maxWidth,
                                                ),
                                                Positioned(
                                                  left: markerPos - 8,
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                        Icons.arrow_drop_down_rounded,
                                                        color: _bmiColor,
                                                        size: 24,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                        // Multi-colored Spectrum Bar
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: SizedBox(
                                            height: 8,
                                            child: Row(
                                              children: [
                                                Expanded(flex: 35, child: Container(color: const Color(0xFF0EA5E9))), // Underweight
                                                const SizedBox(width: 2),
                                                Expanded(flex: 64, child: Container(color: const Color(0xFF10B981))), // Normal
                                                const SizedBox(width: 2),
                                                Expanded(flex: 50, child: Container(color: const Color(0xFFF59E0B))), // Overweight
                                                const SizedBox(width: 2),
                                                Expanded(flex: 50, child: Container(color: const Color(0xFFEF4444))), // Obese
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Spectrum Labels
                                        const Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('<18.5', style: TextStyle(fontSize: 10, color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold)),
                                            Text('18.5 - 24.9', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                            Text('25 - 29.9', style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                                            Text('>30.0', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Section 2: Log Daily Vitals Form
                        _buildSectionHeader(
                          title: 'Log Daily Vitals',
                          subtitle: 'Record blood pressure and fasting blood sugar readings',
                          icon: Icons.edit_note_rounded,
                          iconColor: const Color(0xFFEC4899),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _sysBpController,
                                      label: 'Systolic BP (mmHg)',
                                      hint: 'e.g. 120',
                                      icon: Icons.favorite_border_rounded,
                                      iconColor: const Color(0xFF38BDF8),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildInputField(
                                      controller: _diaBpController,
                                      label: 'Diastolic BP (mmHg)',
                                      hint: 'e.g. 80',
                                      icon: Icons.favorite_rounded,
                                      iconColor: const Color(0xFF0EA5E9),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              _buildInputField(
                                controller: _sugarController,
                                label: 'Fasting Blood Sugar (mg/dL)',
                                hint: 'e.g. 95',
                                icon: Icons.water_drop_rounded,
                                iconColor: const Color(0xFFF43F5E),
                              ),
                              const SizedBox(height: 20),

                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
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
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                                    label: const Text(
                                      'Save Vitals Log',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    onPressed: _addVitalsLogEntry,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Section 3: Vitals History Log
                        _buildSectionHeader(
                          title: 'Vitals History Log',
                          subtitle: 'Your recent recorded health measurements',
                          icon: Icons.history_rounded,
                          iconColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(height: 14),

                        _vitalsLog.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _vitalsLog.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _vitalsLog[index];
                                  return _buildHistoryCard(item, index);
                                },
                              ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Top Header Quick Stat Card Widget
  Widget _buildHeaderStatCard({
    required String title,
    required String value,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: badgeColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? 'N/A' : value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Section Header Generator
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Reusable TextField Generator
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color iconColor,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: Icon(icon, color: iconColor, size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: iconColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // History Card Item Widget
  Widget _buildHistoryCard(Map<String, dynamic> item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'BP: ${item['bp'] ?? 'N/A'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Sugar: ${item['sugar'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.scale_outlined, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${item['weight'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${item['date'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
            onPressed: () => _deleteVitalsEntry(index),
            tooltip: 'Remove entry',
          ),
        ],
      ),
    );
  }

  // Empty State Illustration Widget
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.monitor_heart_outlined, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            'No Vitals Logged Yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your BP and Blood Sugar above to record your first entry.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

