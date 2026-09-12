import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;
  final TextEditingController _idController = TextEditingController();

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

  void _showManualEntryDialog() {
    _idController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.primaryTeal),
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
                  hintText: 'e.g. 1024',
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
                  Navigator.pop(context); // Close dialog
                  Navigator.pushNamed(
                    context,
                    '/check-in',
                    arguments: {'appointmentId': appointmentId},
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid numeric Appointment ID'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              },
              child: const Text('Proceed to Check-In'),
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
          'Scan Patient QR',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        alignment: Alignment.center,
        children: [
          // Background Camera Simulation Graphic
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A),
              child: Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),

          // Central Viewfinder Cutout Frame
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryTeal, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
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

          // Instructions Header & Manual Button Footer
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryTeal, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Align QR code inside the frame to scan',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 50,
            left: 30,
            right: 30,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.primaryTeal, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                    ),
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.edit, color: AppTheme.primaryTeal),
                    label: const Text(
                      'Enter Appointment ID Manually',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
