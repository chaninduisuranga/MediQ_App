import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../widgets/staff_bottom_nav_bar.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;
  final TextEditingController _idController = TextEditingController();
  Map<String, dynamic>? _scannedPatientData;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _processScannedId(int appointmentId) async {
    setState(() {
      _isSearching = true;
      _scannedPatientData = null;
    });

    final data = await QueueService.getAppointmentById(appointmentId);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _scannedPatientData = data;
      });

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment #$appointmentId not found.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showManualEntryDialog() {
    _idController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.primarySkyBlue),
              SizedBox(width: 10),
              Text('Manual ID Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the Appointment ID printed on the patient\'s ticket:',
                style: TextStyle(fontSize: 13, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. 102',
                  labelText: 'Appointment ID',
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              onPressed: () {
                final idText = _idController.text.trim();
                final appointmentId = int.tryParse(idText);
                if (appointmentId != null && appointmentId > 0) {
                  Navigator.pop(context);
                  _processScannedId(appointmentId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid numeric Appointment ID'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              },
              child: const Text('Search & Preview'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        title: const Text(
          'Scan Patient QR Ticket',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard_rounded, color: Colors.white),
            tooltip: 'Enter ID Manually',
            onPressed: _showManualEntryDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Dark camera background
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
          ),

          // Main content column — fully centered and responsive
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ── Instruction Banner ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppTheme.primarySkyBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Align patient QR code inside the frame to scan',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Spacer to push viewfinder to centre ─────────────────
                const Spacer(),

                // ── QR Viewfinder Box ────────────────────────────────────
                if (_scannedPatientData == null)
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primarySkyBlue, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primarySkyBlue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AnimatedBuilder(
                        animation: _scanAnimation,
                        builder: (context, child) {
                          return Stack(
                            children: [
                              Positioned(
                                top: _scanAnimation.value * 240,
                                left: 10,
                                right: 10,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentGreen,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.accentGreen.withValues(alpha: 0.8),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                // ── Scanned patient result card (replaces viewfinder) ────
                if (_scannedPatientData != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'QR SCAN SUCCESSFUL',
                                      style: TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppTheme.mutedText),
                                onPressed: () => setState(() => _scannedPatientData = null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '#${_scannedPatientData!['queue_number'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primarySkyBlue,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _scannedPatientData!['patient_name'] ?? 'Unknown Patient',
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'OPD: ${AppointmentService.getRoomDisplayName(_scannedPatientData!['room'] ?? '')}',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.mutedText, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      'Time: ${_scannedPatientData!['appointment_time'] ?? 'Today'}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGreen),
                              onPressed: () {
                                final apptId = _scannedPatientData!['id'];
                                Navigator.pushNamed(
                                  context,
                                  '/check-in',
                                  arguments: {'appointmentId': apptId},
                                );
                              },
                              icon: const Icon(Icons.how_to_reg_rounded),
                              label: const Text('PROCEED TO CHECK-IN'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Spacer below viewfinder ──────────────────────────────
                const Spacer(),

                // ── Manual Entry Button ──────────────────────────────────
                if (_scannedPatientData == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.primarySkyBlue, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                        ),
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.edit, color: AppTheme.primarySkyBlue),
                        label: const Text(
                          'Enter Appointment ID Manually',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                if (_scannedPatientData != null) const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Loading overlay ──────────────────────────────────────────
          if (_isSearching)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primarySkyBlue),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 2),
    );
  }
}
