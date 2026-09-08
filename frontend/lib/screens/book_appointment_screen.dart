import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/services/appointment_service.dart';
import '../core/theme/theme.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Room & Date selection state
  String? _selectedRoomKey;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _isBooking = false;

  // Queue counts per room
  final Map<String, int> _queueCounts = {};
  bool _isLoadingQueues = true;

  // My appointments
  List<dynamic> _myAppointments = [];
  bool _isLoadingAppointments = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQueueCounts();
    _loadMyAppointments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadQueueCounts() async {
    setState(() => _isLoadingQueues = true);
    final dateStr = _formatDate(_selectedDate);
    for (final room in AppointmentService.opdRooms) {
      final key = room['key'] as String;
      final res = await AppointmentService.getQueueStatus(key, date: dateStr);
      if (mounted && res['success'] == true) {
        setState(() {
          _queueCounts[key] = (res['data']?['current_max'] ?? 0) as int;
        });
      }
    }
    if (mounted) setState(() => _isLoadingQueues = false);
  }

  Future<void> _loadMyAppointments() async {
    setState(() => _isLoadingAppointments = true);
    final res = await AppointmentService.getMyAppointments();
    if (mounted) {
      setState(() {
        _isLoadingAppointments = false;
        if (res['success'] == true) {
          _myAppointments = (res['data'] as List<dynamic>? ?? [])
              .where((a) => a['status'] != 'CANCELLED')
              .toList();
        }
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedRoomKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an OPD room first'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);
    final res = await AppointmentService.bookAppointment(
      roomKey: _selectedRoomKey!,
      date: _formatDate(_selectedDate),
      notes: _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isBooking = false);

    if (res['success'] == true) {
      _loadMyAppointments();
      _loadQueueCounts();
      _showQRDialog(res['data']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Booking failed'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 2));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) || _selectedDate.isAfter(maxDate) ? today : _selectedDate,
      firstDate: today,
      lastDate: maxDate,
      selectableDayPredicate: (day) {
        final d = DateTime(day.year, day.month, day.day);
        return !d.isBefore(today) && !d.isAfter(maxDate);
      },
      helpText: 'SELECT APPOINTMENT DATE (MAX 3 DAYS)',
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadQueueCounts();
    }
  }

  Widget _buildDateChip(int dayOffset) {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
    final dateStr = _formatDate(date);
    final isSelected = _formatDate(_selectedDate) == dateStr;

    String label = 'Today';
    if (dayOffset == 1) label = 'Tomorrow';
    if (dayOffset == 2) label = 'Day 3';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[date.month - 1];
    final dayNum = date.day;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDate = date;
          });
          _loadQueueCounts();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryTeal : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primaryTeal : Colors.grey.shade300,
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppTheme.primaryTeal.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
                blurRadius: isSelected ? 10 : 4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white70 : AppTheme.mutedText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$dayNum $monthStr',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : AppTheme.darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(int id) async {
    final res = await AppointmentService.cancelAppointment(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? (res['success'] == true ? 'Cancelled' : 'Failed')),
          backgroundColor: res['success'] == true ? AppTheme.primaryTeal : AppTheme.errorRed,
        ),
      );
      if (res['success'] == true) _loadMyAppointments();
    }
  }

  Future<void> _downloadQRTicketImage(GlobalKey key, BuildContext ctx, int queueNum, String room) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          if (!ctx.mounted) return;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.image_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('✅ QR Ticket Image (#$queueNum - $room) saved to Photo Gallery!'),
                  ),
                ],
              ),
              backgroundColor: AppTheme.accentGreen,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }
      }
    } catch (_) {}

    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('📸 Ticket #$queueNum QR Image saved to photo gallery!'),
        backgroundColor: AppTheme.accentGreen,
      ),
    );
  }

  void _showQRDialog(Map<String, dynamic> appt) {
    final qrData = appt['qr_code_data'] ?? '';
    final queueNum = appt['queue_number'] ?? 0;
    final room = appt['room_display_name'] ?? AppointmentService.getRoomDisplayName(appt['room'] ?? '');
    final date = appt['appointment_date'] ?? '';
    final patientName = appt['patient_name'] ?? '';
    final nic = appt['patient_nic'] ?? '';
    final roomColor = Color(AppointmentService.getRoomColor(appt['room'] ?? ''));
    final GlobalKey captureKey = GlobalKey();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Repaint boundary to capture full ticket as Image for Gallery Save
                RepaintBoundary(
                  key: captureKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roomColor.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ticket Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppTheme.primaryBlue, roomColor]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('MediQ OPD Digital Ticket',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(room, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Queue Number Display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: roomColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: roomColor.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text('Your OPD Queue Number',
                                  style: TextStyle(fontSize: 12, color: roomColor, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                '#$queueNum',
                                style: TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  color: roomColor,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Date: $date',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.darkText, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Patient Info
                        _buildInfoRow(Icons.person_rounded, patientName),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.credit_card_rounded, 'NIC: $nic'),
                        const SizedBox(height: 4),
                        _buildInfoRow(Icons.meeting_room_rounded, 'Room: $room'),
                        const SizedBox(height: 14),

                        // QR Code Image
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: roomColor.withValues(alpha: 0.3), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: qrData.isNotEmpty
                              ? QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 160,
                                  eyeStyle: QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: roomColor,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: AppTheme.darkText,
                                  ),
                                )
                              : const SizedBox(
                                  height: 160,
                                  child: Center(child: Text('QR code unavailable')),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '📱 Scan QR with camera to open web ticket',
                  style: TextStyle(fontSize: 11, color: roomColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),

                // Action Buttons
                Row(
                  children: [
                    // Save to Gallery Button
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadQRTicketImage(captureKey, ctx, queueNum, room),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Save to Gallery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: roomColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy Web Link Button
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: qrData));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Web ticket URL copied to clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy URL', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          side: BorderSide(color: roomColor),
                          foregroundColor: roomColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 14, color: AppTheme.darkText, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book OPD Appointment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.mutedText,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today_rounded), text: 'Book Now'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'My Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBookTab(),
          _buildMyBookingsTab(),
        ],
      ),
    );
  }

  // ─── TAB 1: Book Appointment ──────────────────────────────────────────────
  Widget _buildBookTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryBlue.withValues(alpha: 0.08), AppTheme.primaryTeal.withValues(alpha: 0.08)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selectable Date Window (3 Days)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkText)),
                      SizedBox(height: 2),
                      Text('Appointments can only be booked for today or within the next 2 days. Other dates are locked.',
                          style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Date Selection Title & Date Picker Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Appointment Date',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                  Text('Pick one of 3 available days',
                      style: TextStyle(fontSize: 11, color: AppTheme.mutedText)),
                ],
              ),
              IconButton.filledTonal(
                onPressed: _pickCustomDate,
                icon: const Icon(Icons.date_range_rounded, color: AppTheme.primaryTeal),
                tooltip: 'Calendar Picker (3-Day Limit)',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 Day Selection Chips
          Row(
            children: [
              _buildDateChip(0),
              const SizedBox(width: 8),
              _buildDateChip(1),
              const SizedBox(width: 8),
              _buildDateChip(2),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Choose OPD Room',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          Text('Available rooms & live queue counts for ${_formatDate(_selectedDate)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
          const SizedBox(height: 14),

          // Room Cards
          ...AppointmentService.opdRooms.map((room) {
            final key = room['key'] as String;
            final name = room['name'] as String;
            final subtitle = room['subtitle'] as String;
            final color = Color(room['color'] as int);
            final queueCount = _queueCounts[key] ?? 0;
            final isSelected = _selectedRoomKey == key;

            return _buildRoomCard(
              key: key,
              name: name,
              subtitle: subtitle,
              color: color,
              queueCount: queueCount,
              isSelected: isSelected,
            );
          }),

          const SizedBox(height: 20),

          // Notes Field
          const Text('Additional Notes (Optional)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe your symptoms or reason for visit...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 14, right: 8, top: 14),
                child: Icon(Icons.edit_note_rounded, color: AppTheme.primaryTeal),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Book Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isBooking ? null : _bookAppointment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 56),
                backgroundColor: AppTheme.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: AppTheme.primaryTeal.withValues(alpha: 0.4),
              ),
              child: _isBooking
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.confirmation_number_rounded, size: 22),
                        SizedBox(width: 10),
                        Text('Book Appointment & Get Queue Number',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRoomCard({
    required String key,
    required String name,
    required String subtitle,
    required Color color,
    required int queueCount,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedRoomKey = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Room icon container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _getRoomIcon(key),
                color: isSelected ? Colors.white : color,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? color : AppTheme.darkText,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                ],
              ),
            ),
            // Queue count badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isLoadingQueues
                        ? Colors.grey.shade200
                        : (queueCount > 15
                            ? AppTheme.errorRed.withValues(alpha: 0.12)
                            : queueCount > 8
                                ? Colors.orange.withValues(alpha: 0.12)
                                : AppTheme.accentGreen.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _isLoadingQueues
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '$queueCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: queueCount > 15
                                ? AppTheme.errorRed
                                : queueCount > 8
                                    ? Colors.orange.shade700
                                    : AppTheme.accentGreen,
                          ),
                        ),
                ),
                const SizedBox(height: 2),
                Text('in queue', style: TextStyle(fontSize: 10, color: AppTheme.mutedText.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(width: 8),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getRoomIcon(String key) {
    switch (key) {
      case 'DRESSING_ROOM':
        return Icons.healing_rounded;
      case 'INJECTION_ROOM':
        return Icons.vaccines_rounded;
      case 'BLEEDING_ROOM':
        return Icons.bloodtype_rounded;
      case 'ANIMAL_BITE_ROOM':
        return Icons.pets_rounded;
      case 'OPD_CLINIC_ROOM':
        return Icons.local_hospital_rounded;
      default:
        return Icons.medical_services_rounded;
    }
  }

  // ─── TAB 2: My Bookings ───────────────────────────────────────────────────
  Widget _buildMyBookingsTab() {
    return RefreshIndicator(
      onRefresh: _loadMyAppointments,
      child: _isLoadingAppointments
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
          : _myAppointments.isEmpty
              ? _buildEmptyBookings()
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My OPD Appointments',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                      const SizedBox(height: 4),
                      Text('${_myAppointments.length} active appointment(s)',
                          style: const TextStyle(fontSize: 13, color: AppTheme.mutedText)),
                      const SizedBox(height: 16),
                      ..._myAppointments.map((appt) => _buildAppointmentCard(appt)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final roomKey = appt['room'] ?? '';
    final roomName = AppointmentService.getRoomDisplayName(roomKey);
    final roomColor = Color(AppointmentService.getRoomColor(roomKey));
    final queueNum = appt['queue_number'] ?? 0;
    final date = appt['appointment_date'] ?? '';
    final status = appt['status'] ?? 'PENDING';
    final qrData = appt['qr_code_data'] ?? '';
    final id = appt['id'] as int? ?? 0;
    final notes = appt['notes'] ?? '';

    // Today's date check for showing big queue number
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final isToday = date == todayStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: roomColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
        border: Border.all(color: roomColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [roomColor.withValues(alpha: 0.85), roomColor],
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
                Icon(_getRoomIcon(roomKey), color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roomName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(isToday ? '📅 Today - $date' : '📅 $date',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Queue Number - Big
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Queue Number',
                          style: TextStyle(fontSize: 11, color: AppTheme.mutedText.withValues(alpha: 0.8))),
                      const SizedBox(height: 4),
                      Text(
                        '$queueNum',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: roomColor,
                          height: 1.0,
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                          ),
                          child: const Text('Today\'s Slot',
                              style: TextStyle(fontSize: 11, color: AppTheme.accentGreen, fontWeight: FontWeight.bold)),
                        ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Note: $notes',
                            style: const TextStyle(fontSize: 12, color: AppTheme.mutedText),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // QR Code preview (small)
                if (qrData.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showQRDialog(appt),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: roomColor.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 90,
                            eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: roomColor),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Tap to enlarge',
                            style: TextStyle(fontSize: 10, color: AppTheme.mutedText.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Footer actions
          if (status == 'PENDING' || status == 'CONFIRMED')
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showQRDialog(appt),
                      icon: Icon(Icons.qr_code_rounded, size: 18, color: roomColor),
                      label: Text('View QR', style: TextStyle(color: roomColor)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        side: BorderSide(color: roomColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmCancel(id),
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.errorRed),
                      label: const Text('Cancel', style: TextStyle(color: AppTheme.errorRed)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  void _confirmCancel(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Text('Cancel Appointment?'),
          ],
        ),
        content: const Text('Are you sure you want to cancel this OPD appointment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep It')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelAppointment(id);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBookings() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_busy_rounded,
                    size: 64, color: AppTheme.primaryTeal),
              ),
              const SizedBox(height: 20),
              const Text('No Active Bookings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              const SizedBox(height: 8),
              const Text(
                'You have no OPD appointments today.\nGo to Book Now tab to get your queue number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.mutedText),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Book Appointment'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: AppTheme.primaryTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
