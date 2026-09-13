import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});

  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  final List<Map<String, dynamic>> _symptomCategories = [
    {
      'id': 'opd_clinic',
      'title': 'Fever, Cough & Body Pain',
      'titleSi': 'කැස්ස, හෙම්බිරිස්සාව & ඇඟපත',
      'icon': Icons.health_and_safety_rounded,
      'room': 'OPD Clinic Room (4 Doctors)',
      'color': const Color(0xFF2563EB),
      'advice': 'General OPD consultation room with 4 doctors attending to patients for fever, cold & aches.',
      'checklist': [
        'Bring National Identity Card (NIC / Passport)',
        'Bring previous doctor prescriptions & health records',
        'Collect queue token and wait for allocated doctor counter',
      ],
    },
    {
      'id': 'dressing',
      'title': 'Wounds, Cuts & Boils',
      'titleSi': 'තුවාල, ගෙඩි & බෙහෙත් දැමීම',
      'icon': Icons.healing_rounded,
      'room': 'Dressing Room',
      'color': const Color(0xFFF59E0B),
      'advice': 'Wound cleaning, dressing, and bandage re-application room.',
      'checklist': [
        'Keep wound area clean & covered before procedure',
        'Inform nursing staff if wound has active bleeding',
        'Bring OPD ticket slip from registration counter',
      ],
    },
    {
      'id': 'injection',
      'title': 'Prescribed Injections',
      'titleSi': 'ඉන්ජෙක්ෂන් (විදීම්) ලබාගැනීම',
      'icon': Icons.vaccines_rounded,
      'room': 'Injection Room',
      'color': const Color(0xFF8B5CF6),
      'advice': 'Queue for patients prescribed IM/IV injection shots by doctors.',
      'checklist': [
        'Must present valid doctor injection chit/prescription',
        'Inform staff of any known drug or penicillin allergies',
        'Wait in room observation area for 5 mins after shot',
      ],
    },
    {
      'id': 'animal_bite',
      'title': 'Animal Bite Treatment',
      'titleSi': 'සතුන් හපාකෑම & රේබීස් එන්නත',
      'icon': Icons.pets_rounded,
      'room': 'Animal Bite Room',
      'color': const Color(0xFFEF4444),
      'advice': 'Dedicated queue & doctor for dog/cat/animal bites and Anti-Rabies vaccination.',
      'checklist': [
        'Wash bite wound with soap & running water for 15 mins',
        'Immediate priority counter - present to triage right away',
        'Bring Anti-Rabies Vaccination (ARV) card if follow-up dose',
      ],
    },
    {
      'id': 'bleeding',
      'title': 'Blood Sample Draw',
      'titleSi': 'ලේ ලබාදීම (Bleeding Room)',
      'icon': Icons.water_drop_rounded,
      'room': 'Bleeding Room',
      'color': const Color(0xFFEC4899),
      'advice': 'Combined queue for registered OPD patients and external clinic referral chits for blood draws.',
      'checklist': [
        'Bring blood test request chit from doctor / clinic',
        'Maintain required fasting hours (FBS/Lipid Profile 8-12 hrs)',
        'Joint queue for both OPD and outside clinic patients',
      ],
    },
  ];

  String _selectedSymptomId = 'opd_clinic';
  int _severity = 1; // 0: Mild, 1: Moderate, 2: High

  @override
  Widget build(BuildContext context) {
    final selectedItem = _symptomCategories.firstWhere(
      (element) => element['id'] == _selectedSymptomId,
      orElse: () => _symptomCategories[0],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('OPD Symptom Checker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3D Glassmorphic Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart OPD Guide',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select your symptom to find your hospital room & queue instructions.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              '1. Select Primary Symptom / Queue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),

            // Symptom Selection Grid (2-Column 3D Glass)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _symptomCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.28,
              ),
              itemBuilder: (context, index) {
                final cat = _symptomCategories[index];
                final isSelected = cat['id'] == _selectedSymptomId;
                final Color catColor = cat['color'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSymptomId = cat['id'];
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? catColor.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? catColor : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? catColor.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.03),
                          blurRadius: isSelected ? 10 : 4,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat['icon'], color: catColor, size: 20),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: catColor, size: 18),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat['title'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            color: isSelected ? catColor : const Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat['titleSi'],
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text(
              '2. Symptom Intensity Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildSeverityChip(0, 'Mild (සුළු)', const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildSeverityChip(1, 'Moderate (මධ්‍යස්ථ)', const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildSeverityChip(2, 'Severe (දරුණු)', const Color(0xFFEF4444)),
              ],
            ),

            const SizedBox(height: 24),

            // Triage Recommendation Result Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: selectedItem['color'].withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: selectedItem['color'].withValues(alpha: 0.1),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selectedItem['color'].withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'RECOMMENDED CLINIC',
                          style: TextStyle(
                            color: selectedItem['color'],
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (_severity == 2)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: AppTheme.errorRed),
                              SizedBox(width: 4),
                              Text('High Priority', style: TextStyle(fontSize: 10, color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedItem['room'],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: selectedItem['color']),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Guidance: ${selectedItem['advice']}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  const Text('📋 OPD Pre-Visit Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  if (selectedItem['checklist'] != null)
                    ...List.generate(
                      (selectedItem['checklist'] as List<String>).length,
                      (i) => _buildCheckItem(selectedItem['checklist'][i]),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Book Appointment Button
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 10,
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
                  icon: const Icon(Icons.event_available_rounded, color: Colors.white),
                  label: const Text('Book OPD Appointment Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () {
                    Navigator.pushNamed(context, '/book-appointment');
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(int level, String label, Color color) {
    final isSelected = _severity == level;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _severity = level;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }
}
