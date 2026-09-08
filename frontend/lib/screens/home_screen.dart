import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/services/appointment_service.dart';
import '../core/services/auth_service.dart';
import '../core/theme/theme.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type; // 'TODAY', '1_DAY', '2_DAYS', 'BOOKED'
  final String dateStr;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.dateStr,
    required this.timestamp,
    this.isRead = false,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  Map<String, dynamic>? _nextAppointment;
  bool _isLoadingAppointment = true;

  // Notifications State
  List<AppNotification> _notifications = [];

  int get _unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _fetchNextAppointment();
    // Ticking timer every second to update countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _nextAppointment != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNextAppointment() async {
    final res = await AppointmentService.getMyAppointments();
    if (mounted) {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      setState(() {
        _isLoadingAppointment = false;
        if (res['success'] == true) {
          // Filter out CANCELLED appointments and past dates (auto-remove after appointment date)
          final activeList = (res['data'] as List<dynamic>? ?? [])
              .where((a) {
                final status = a['status'] as String? ?? '';
                final apptDate = a['appointment_date'] as String? ?? '';
                return status != 'CANCELLED' && apptDate.compareTo(todayStr) >= 0;
              })
              .toList();

          if (activeList.isNotEmpty) {
            activeList.sort((a, b) => (a['appointment_date'] as String).compareTo(b['appointment_date'] as String));
            _nextAppointment = activeList.first as Map<String, dynamic>;
          } else {
            _nextAppointment = null;
          }

          // Generate dynamic notifications for active appointments
          _generateNotifications(activeList, todayStr);
        }
      });
    }
  }

  void _generateNotifications(List<dynamic> activeAppointments, String todayStr) {
    final List<AppNotification> list = [];
    final now = DateTime.now();

    for (final appt in activeAppointments) {
      final id = (appt['id'] ?? 0).toString();
      final dateStr = appt['appointment_date'] as String? ?? '';
      final roomKey = appt['room'] as String? ?? '';
      final roomName = AppointmentService.getRoomDisplayName(roomKey);
      final queueNum = appt['queue_number'] ?? 0;

      // Calculate days left
      int daysLeft = 0;
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final year = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final day = int.parse(parts[2]);
          final apptDate = DateTime(year, month, day);
          final todayDate = DateTime(now.year, now.month, now.day);
          daysLeft = apptDate.difference(todayDate).inDays;
        }
      } catch (_) {}

      // 1. Reminder notification based on remaining days
      if (daysLeft == 0) {
        list.add(AppNotification(
          id: '${id}_today',
          title: '🚨 Appointment Reminder (TODAY!)',
          message: 'Your appointment for $roomName (Token #$queueNum) is TODAY! Please present your QR ticket at the OPD counter.',
          type: 'TODAY',
          dateStr: dateStr,
          timestamp: now,
        ));
      } else if (daysLeft == 1) {
        list.add(AppNotification(
          id: '${id}_1day',
          title: '⏰ 1 Day Remaining',
          message: 'Reminder: Only 1 day remaining for your $roomName appointment tomorrow ($dateStr). Token #$queueNum.',
          type: '1_DAY',
          dateStr: dateStr,
          timestamp: now,
        ));
      } else if (daysLeft == 2) {
        list.add(AppNotification(
          id: '${id}_2days',
          title: '📅 2 Days Remaining',
          message: 'Reminder: 2 days remaining for your $roomName appointment on $dateStr. Token #$queueNum.',
          type: '2_DAYS',
          dateStr: dateStr,
          timestamp: now,
        ));
      }

      // 2. Booking confirmation notification
      list.add(AppNotification(
        id: '${id}_booked',
        title: '✅ OPD Booking Confirmed',
        message: 'Your slot for $roomName on $dateStr (Queue #$queueNum) has been successfully registered.',
        type: 'BOOKED',
        dateStr: dateStr,
        timestamp: now.subtract(const Duration(minutes: 5)),
      ));
    }

    _notifications = list;
  }

  Duration _getTimeRemaining(String appointmentDateStr) {
    try {
      final parts = appointmentDateStr.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        // Target: 08:00 AM on appointment date
        final targetDate = DateTime(year, month, day, 8, 0, 0);
        final now = DateTime.now();

        if (targetDate.isAfter(now)) {
          return targetDate.difference(now);
        }
      }
    } catch (_) {}
    return Duration.zero;
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
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
              children: [
                // Top handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Sheet Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppTheme.errorRed, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notifications',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.darkText)),
                          Text('${_notifications.length} total alert(s)',
                              style: const TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                        ],
                      ),
                      const Spacer(),
                      if (_notifications.any((n) => !n.isRead))
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (var n in _notifications) {
                                n.isRead = true;
                              }
                            });
                            setModalState(() {});
                          },
                          child: const Text('Mark all as read',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Notification List
                Expanded(
                  child: _notifications.isEmpty
                      ? _buildEmptyNotifications()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, index) {
                            final item = _notifications[index];
                            return _buildNotificationCard(item, () async {
                              setState(() {
                                item.isRead = true;
                              });
                              setModalState(() {});
                              Navigator.pop(ctx);
                              await _openBookAppointment();
                            });
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification item, VoidCallback onTap) {
    Color badgeColor = AppTheme.primaryTeal;
    IconData badgeIcon = Icons.notifications_rounded;

    if (item.type == 'TODAY') {
      badgeColor = AppTheme.errorRed;
      badgeIcon = Icons.warning_amber_rounded;
    } else if (item.type == '1_DAY' || item.type == '2_DAYS') {
      badgeColor = Colors.orange.shade700;
      badgeIcon = Icons.timer_rounded;
    } else if (item.type == 'BOOKED') {
      badgeColor = AppTheme.accentGreen;
      badgeIcon = Icons.check_circle_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : badgeColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? Colors.grey.shade200 : badgeColor.withValues(alpha: 0.3),
            width: item.isRead ? 1 : 1.5,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(badgeIcon, color: badgeColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: const TextStyle(fontSize: 12, color: AppTheme.mutedText, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '📅 Date: ${item.dateStr}',
                    style: TextStyle(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotifications() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.mutedText.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_rounded, size: 48, color: AppTheme.mutedText),
          ),
          const SizedBox(height: 14),
          const Text('No Notifications Yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          const Text('Book an OPD appointment to receive live reminder alerts.',
              style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
        ],
      ),
    );
  }

  Future<void> _openBookAppointment() async {
    await Navigator.pushNamed(context, '/book-appointment');
    if (mounted) {
      _fetchNextAppointment();
    }
  }

  Future<void> _openMedicalRecords() async {
    await Navigator.pushNamed(context, '/medical-records');
    if (mounted) {
      _fetchNextAppointment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Patient';
    final nic = user['nic'] ?? 'N/A';
    final phone = user['phone'] ?? 'N/A';
    final bloodGroup = user['blood_group'] ?? 'N/A';
    final district = user['district'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu_rounded, size: 28),
              tooltip: 'Open Menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 34,
              height: 34,
              errorBuilder: (_, __, ___) => const Icon(Icons.local_hospital, color: AppTheme.primaryTeal),
            ),
            const SizedBox(width: 10),
            const Text(
              'MediQ OPD Portal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          // Red Bell Notification Icon with Unread Count Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_active_rounded, color: AppTheme.errorRed, size: 26),
                tooltip: 'Appointment Notifications',
                onPressed: _showNotificationsSheet,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorRed.withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '${_unreadNotificationCount > 9 ? '9+' : _unreadNotificationCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      // Navigation Drawer
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryTeal],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                ),
              ),
              accountName: Text(
                fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text('NIC: $nic | Phone: $phone'),
            ),

            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryTeal),
              title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.primaryTeal),
              title: const Text('OPD Live Queue', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _openBookAppointment();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_note_outlined, color: AppTheme.primaryTeal),
              title: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _openBookAppointment();
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services_outlined, color: AppTheme.primaryTeal),
              title: const Text('Medical Records & History', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _openMedicalRecords();
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_in_talk_outlined, color: Color(0xFFEF4444)),
              title: const Text('Emergency SOS (1990)', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Calling Suwa Seriya 1990 Emergency Hotline...')),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppTheme.mutedText),
              title: const Text('App Information', style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'MediQ OPD Portal',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Government OPD - Closer to You',
                );
              },
            ),

            const Spacer(),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: const Text(
                'Logout Account',
                style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _fetchNextAppointment,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Glassmorphism Welcome Card
              _build3DGlassmorphicWelcomeCard(
                fullName: fullName,
                nic: nic,
                phone: phone,
                bloodGroup: bloodGroup,
                district: district,
                onTapProfile: () => Navigator.pushNamed(context, '/profile'),
              ),

              // Sleek, Reduced-Height Live Countdown / Ticket Card (Only shown if active appointment exists)
              if (_nextAppointment != null) ...[
                const SizedBox(height: 16),
                _buildCountdownSection(),
              ],

              const SizedBox(height: 24),

              const Text(
                'OPD Services',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),

              // 3D Glassmorphism Grid Cards
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _build3DGlassCard(
                    icon: Icons.confirmation_number_outlined,
                    title: 'OPD Live Queue',
                    subtitle: 'Check live token status',
                    gradientColors: [const Color(0xFF0077B6), const Color(0xFF0096C7)],
                    onTap: _openBookAppointment,
                  ),
                  _build3DGlassCard(
                    icon: Icons.event_note_outlined,
                    title: 'Book Appointment',
                    subtitle: 'Schedule OPD Visit',
                    gradientColors: [const Color(0xFF00A896), const Color(0xFF02C39A)],
                    onTap: _openBookAppointment,
                  ),
                  _build3DGlassCard(
                    icon: Icons.medical_services_outlined,
                    title: 'Medical Records',
                    subtitle: 'Prescriptions & History',
                    gradientColors: [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
                    onTap: _openMedicalRecords,
                  ),
                  _build3DGlassCard(
                    icon: Icons.contact_support_outlined,
                    title: 'Emergency 1990',
                    subtitle: 'Suwa Seriya Ambulance',
                    gradientColors: [const Color(0xFFE11D48), const Color(0xFFF43F5E)],
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Emergency Hotline: Dial 1990')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Compact Live Countdown & Ticket Card Widget ─────────────────────────
  Widget _buildCountdownSection() {
    if (_isLoadingAppointment) {
      return Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal, strokeWidth: 2.5)),
      );
    }

    // No active appointment (or expired appointment date)
    if (_nextAppointment == null) {
      return const SizedBox.shrink();
    }

    final appt = _nextAppointment!;
    final dateStr = appt['appointment_date'] ?? '';
    final roomKey = appt['room'] ?? '';
    final roomName = AppointmentService.getRoomDisplayName(roomKey);
    final roomColor = Color(AppointmentService.getRoomColor(roomKey));
    final queueNum = appt['queue_number'] ?? 0;
    final qrData = appt['qr_code_data'] ?? '';

    final remaining = _getTimeRemaining(dateStr);
    final isCountdownFinished = remaining == Duration.zero;

    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return GestureDetector(
      onTap: _openBookAppointment,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              roomColor,
              AppTheme.primaryBlue,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: roomColor.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCountdownFinished
                        ? AppTheme.accentGreen.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCountdownFinished ? AppTheme.accentGreen : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCountdownFinished ? Icons.check_circle_rounded : Icons.timer_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCountdownFinished ? 'SLOT ACTIVE TODAY' : 'COUNTDOWN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '📅 $dateStr',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Content Area - Switch between Countdown and Ticket display (Same compact height!)
            if (!isCountdownFinished) ...[
              // ── STATE A: Live Countdown Active ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Queue #$queueNum',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Compact Live Ticking Digit Boxes
                  Row(
                    children: [
                      _buildTimerDigitBox(days.toString().padLeft(2, '0'), 'd'),
                      _buildTimerSep(),
                      _buildTimerDigitBox(hours.toString().padLeft(2, '0'), 'h'),
                      _buildTimerSep(),
                      _buildTimerDigitBox(minutes.toString().padLeft(2, '0'), 'm'),
                      _buildTimerSep(),
                      _buildTimerDigitBox(seconds.toString().padLeft(2, '0'), 's'),
                    ],
                  ),
                ],
              ),
            ] else ...[
              // ── STATE B: Countdown Finished (Today's Ticket Display) ───────
              Row(
                children: [
                  // Big Queue Number
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text('TOKEN', style: TextStyle(fontSize: 9, color: roomColor, fontWeight: FontWeight.bold)),
                        Text(
                          '#$queueNum',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: roomColor,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Present QR at counter',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // QR Mini Code / Ticket Action
                  if (qrData.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 42,
                        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: roomColor),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppTheme.darkText,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 36),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Stylish Compact Timer Digit Box matching MediQ color palette
  Widget _buildTimerDigitBox(String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 2),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSep() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
    );
  }

  // 3D Glassmorphism Welcome Card Widget
  Widget _build3DGlassmorphicWelcomeCard({
    required String fullName,
    required String nic,
    required String phone,
    required String bloodGroup,
    required String district,
    required VoidCallback onTapProfile,
  }) {
    return GestureDetector(
      onTap: onTapProfile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0077B6),
              Color(0xFF00A896),
              Color(0xFF02C39A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A896).withValues(alpha: 0.35),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'NIC: $nic | Phone: $phone',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildHeaderTag('Blood Group', bloodGroup),
                _buildHeaderTag('District', district),
                _buildHeaderTag('Role', 'PATIENT'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTag(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // 3D Glassmorphism OPD Grid Card Widget
  Widget _build3DGlassCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: gradientColors.first.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
