import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class CheckInScreen extends StatefulWidget {
  final int? initialAppointmentId;

  const CheckInScreen({super.key, this.initialAppointmentId});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _appointmentId;
  Map<String, dynamic>? _appointmentData;
  bool _isLoading = false;
  bool _isCheckingIn = false;
  String? _errorMessage;
  Map<String, dynamic>? _checkInSummary;

  @override
  void initState() {
    super.initState();
    if (widget.initialAppointmentId != null) {
      _appointmentId = widget.initialAppointmentId;
      _searchController.text = _appointmentId.toString();
      _fetchAppointmentDetails();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appointmentData == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('appointmentId')) {
        final id = args['appointmentId'] as int?;
        if (id != null && id != _appointmentId) {
          setState(() {
            _appointmentId = id;
            _searchController.text = id.toString();
          });
          _fetchAppointmentDetails();
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAppointmentDetails() async {
    final idText = _searchController.text.trim();
    final id = int.tryParse(idText) ?? _appointmentId;

    if (id == null || id <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid numeric Appointment ID';
        _appointmentData = null;
        _checkInSummary = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _checkInSummary = null;
    });

    final data = await QueueService.getAppointmentById(id);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null) {
          _appointmentId = id;
          _appointmentData = data;
        } else {
          _appointmentData = null;
          _errorMessage = 'Appointment #$id not found in database.';
        }
      });
    }
  }

  Future<void> _handleConfirmCheckIn() async {
    if (_appointmentId == null || _appointmentData == null || _isCheckingIn) return;

    setState(() => _isCheckingIn = true);
    final result = await QueueService.checkInPatientWithDetails(_appointmentId!);

    if (mounted) {
      setState(() {
        _isCheckingIn = false;
        if (result['success'] == true) {
          _appointmentData!['status'] = 'CHECKED_IN';
          _checkInSummary = result;
        }
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient Token #${result['token']} Checked-In Successfully!'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update check-in status. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _appointmentData != null;
    final status = hasData ? (_appointmentData!['status'] as String? ?? 'PENDING') : '';
    final isAlreadyCheckedIn = status == 'CHECKED_IN';
    final isCompleted = status == 'COMPLETED';

    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.checkIn),
      appBar: AppBar(
        title: const Text(
          'Patient Check-In Counter',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search / ID Lookup Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lookup Appointment Ticket',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkText),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Enter Appointment ID (e.g. 103)',
                            prefixIcon: const Icon(Icons.search_rounded),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onSubmitted: (_) => _fetchAppointmentDetails(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _fetchAppointmentDetails,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(80, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Find'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (hasData) ...[
              const SizedBox(height: 20),

              // Patient Detail Confirmation Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Queue Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUEUE TOKEN',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mutedText, letterSpacing: 0.5),
                            ),
                            Text(
                              '#${_appointmentData!['queue_number'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: AppTheme.primarySkyBlue),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAlreadyCheckedIn
                                ? AppTheme.accentGreen.withValues(alpha: 0.15)
                                : (isCompleted ? AppTheme.primaryBlue.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isAlreadyCheckedIn
                                  ? AppTheme.accentGreen
                                  : (isCompleted ? AppTheme.primaryBlue : Colors.orange.shade800),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Detail rows
                    _buildDetailRow('Patient Name', _appointmentData!['patient_name'] ?? 'N/A', Icons.person_outline),
                    _buildDetailRow('NIC Number', _appointmentData!['patient_nic'] ?? 'N/A', Icons.badge_outlined),
                    _buildDetailRow('Phone Number', _appointmentData!['patient_phone'] ?? 'N/A', Icons.phone_outlined),
                    _buildDetailRow(
                      'OPD Room',
                      AppointmentService.getRoomDisplayName(_appointmentData!['room'] ?? ''),
                      Icons.meeting_room_outlined,
                    ),
                    _buildDetailRow('Appointment Date', _appointmentData!['appointment_date'] ?? 'N/A', Icons.calendar_today_outlined),
                    _buildDetailRow('Appointment Time', _appointmentData!['appointment_time'] ?? 'N/A', Icons.access_time_rounded),
                    if ((_appointmentData!['notes'] ?? '').toString().isNotEmpty)
                      _buildDetailRow('Notes', _appointmentData!['notes'], Icons.note_outlined),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Post Check-In Generated Summary (Token, Wait Time, Patients Before)
              if (_checkInSummary != null || isAlreadyCheckedIn)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'PATIENT CHECKED IN!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${_appointmentData!['queue_number'] ?? 'G-012'}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.primarySkyBlue),
                              ),
                              const Text('Token Number', style: TextStyle(fontSize: 11, color: AppTheme.mutedText)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${_checkInSummary?['estimated_wait_minutes'] ?? 15} min',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                              ),
                              const Text('Estimated Wait', style: TextStyle(fontSize: 11, color: AppTheme.mutedText)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${_checkInSummary?['waiting_before'] ?? 5}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.darkText),
                              ),
                              const Text('Patients Before You', style: TextStyle(fontSize: 11, color: AppTheme.mutedText)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Confirm & Check In Action Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: (isAlreadyCheckedIn || isCompleted || _isCheckingIn) ? null : _handleConfirmCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isCheckingIn
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(isAlreadyCheckedIn ? Icons.check_circle_rounded : Icons.how_to_reg_rounded, size: 24),
                  label: Text(
                    isAlreadyCheckedIn
                        ? 'PATIENT ALREADY CHECKED-IN'
                        : (isCompleted ? 'APPOINTMENT COMPLETED' : 'CHECK-IN PATIENT'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.mutedText),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedText, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: AppTheme.darkText, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
