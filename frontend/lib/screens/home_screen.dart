import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/services/appointment_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
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
    AuthService.loadSavedProfilePhoto();
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

  void _showEmergencyHelplineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk_rounded, color: AppTheme.errorRed, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'OPD Emergency & Helplines',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHelplineItem(
              icon: Icons.emergency_rounded,
              title: '1990 Suwa Seriya Ambulance',
              subtitle: 'Free 24/7 National Emergency Hotline',
              phone: '1990',
              color: const Color(0xFFEF4444),
            ),
            const Divider(height: 16),
            _buildHelplineItem(
              icon: Icons.local_hospital_rounded,
              title: 'National Hospital OPD Triage',
              subtitle: 'OPD Reception & Emergency Gate',
              phone: '011-2691111',
              color: AppTheme.primaryTeal,
            ),
            const Divider(height: 16),
            _buildHelplineItem(
              icon: Icons.medication_rounded,
              title: 'OPD Pharmacy Desk',
              subtitle: 'Prescription & Drug Inquiries',
              phone: '011-2691111 (Ext 402)',
              color: const Color(0xFF8B5CF6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.mutedText, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelplineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String phone,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.mutedText)),
              const SizedBox(height: 2),
              Text(phone, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ],
    );
  }

  void _showHospitalGuideSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.map_outlined, color: AppTheme.primaryTeal, size: 24),
                SizedBox(width: 10),
                Text('OPD Hospital Counter Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Floor plan and key counter locations for OPD visitors', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildGuideStep('Counter 1 (Main Lobby)', 'Token generation, patient registration & NIC verification.', Icons.confirmation_number_outlined, AppTheme.primaryBlue),
                  _buildGuideStep('Room 4 (General OPD)', 'Doctor consultation for fever, cold, body pain & general ailments.', Icons.healing_outlined, const Color(0xFF0077B6)),
                  _buildGuideStep('Room 7 (Dressing Room)', 'Wound cleaning, dressing change, and minor surgical care.', Icons.medical_services_outlined, const Color(0xFFF59E0B)),
                  _buildGuideStep('Room 2 (Injection Room)', 'Administration of doctor-prescribed IM & IV injection doses.', Icons.vaccines_outlined, const Color(0xFF8B5CF6)),
                  _buildGuideStep('Bleeding Room (Lab)', 'Blood sample collection & diagnostic blood draws.', Icons.water_drop_outlined, const Color(0xFFEC4899)),
                  _buildGuideStep('Pharmacy Counter 1-4', 'Free OPD medicine collection with prescription chit.', Icons.medication_outlined, const Color(0xFF059669)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String title, String desc, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.darkText, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFamilyProfilesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: Color(0xFF8B5CF6)),
            SizedBox(width: 10),
            Text('Family OPD Cards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryTeal,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(AuthService.currentUser?['full_name'] ?? 'Primary Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Primary Account (Self)', style: TextStyle(fontSize: 11, color: AppTheme.accentGreen)),
              trailing: const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen),
            ),
            const Divider(),
            const Text('Manage OPD tokens for your family members from a single account.', style: TextStyle(fontSize: 11, color: AppTheme.mutedText), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryTeal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, color: AppTheme.primaryTeal),
              label: const Text('Add Family Member', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Family profile feature linked to Primary NIC.')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLanguageSelectorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: AppTheme.primaryTeal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LanguageService.tr('select_language'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(ctx, code: 'en', title: 'English'),
            const Divider(height: 1),
            _buildLanguageOption(ctx, code: 'si', title: 'සිංහල (Sinhala)'),
            const Divider(height: 1),
            _buildLanguageOption(ctx, code: 'ta', title: 'தமிழ் (Tamil)'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext ctx, {required String code, required String title}) {
    final isSelected = LanguageService.currentLanguage == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppTheme.primaryTeal : AppTheme.darkText,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryTeal) : null,
      onTap: () async {
        await LanguageService.setLanguage(code);
        if (ctx.mounted) {
          Navigator.pop(ctx);
        }
      },
    );
  }

  void _showAppSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.settings_outlined, color: AppTheme.darkText),
            const SizedBox(width: 10),
            Text(LanguageService.tr('app_settings'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded, color: AppTheme.primaryTeal),
              title: Text(LanguageService.tr('menu_language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('English / සිංහල / தமிழ்'),
              trailing: Text(
                LanguageService.currentLanguage == 'si'
                    ? 'සිංහල'
                    : LanguageService.currentLanguage == 'ta'
                        ? 'தமிழ்'
                        : 'English',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showLanguageSelectorDialog();
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryTeal),
              title: const Text('Appointment Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Receive token SMS & push notifications'),
              value: true,
              activeThumbColor: AppTheme.primaryTeal,
              onChanged: (val) {},
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LanguageService.tr('close'))),
        ],
      ),
    );
  }

  void _showHelpFaqSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: Color(0xFF059669), size: 24),
                SizedBox(width: 10),
                Text('OPD Help & FAQ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: const [
                  ExpansionTile(
                    title: Text('How do I receive an OPD token?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('You can book an OPD token directly on MediQ portal or scan your appointment QR code at OPD Counter 1 upon hospital arrival.', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('What are the hospital OPD hours?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('OPD counter opens from 7:30 AM to 4:00 PM daily. Emergency triage runs 24/7.', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('Is medicine free at OPD pharmacy?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Yes, all doctor-prescribed medications issued at the government OPD pharmacy are completely free of charge.', style: TextStyle(fontSize: 12, color: AppTheme.mutedText)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser ?? {};
    final fullName = user['full_name'] ?? 'Patient';
    final nic = user['nic'] ?? 'N/A';
    final phone = user['phone'] ?? 'N/A';
    final bloodGroup = user['blood_group'] ?? 'N/A';
    final district = user['district'] ?? 'N/A';

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, lang, child) {
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
            Text(
              LanguageService.tr('app_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
              currentAccountPicture: ValueListenableBuilder<String?>(
                valueListenable: AuthService.profilePhotoNotifier,
                builder: (context, photoPath, _) {
                  final hasPhoto = photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();
                  return CircleAvatar(
                    backgroundColor: Colors.white,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: hasPhoto
                          ? Image.file(
                              File(photoPath),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            )
                          : Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                    ),
                  );
                },
              ),
              accountName: Text(
                fullName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text('NIC: $nic | Phone: $phone'),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryTeal),
                    title: Text(LanguageService.tr('menu_my_profile'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  ListTile(
                    leading: Stack(
                      children: [
                        const Icon(Icons.notifications_none_rounded, color: AppTheme.primaryTeal),
                        if (_unreadNotificationCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppTheme.errorRed, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                    title: Text(LanguageService.tr('menu_notifications'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: _unreadNotificationCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppTheme.errorRed, borderRadius: BorderRadius.circular(10)),
                            child: Text('$_unreadNotificationCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _showNotificationsSheet();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.family_restroom_rounded, color: Color(0xFF8B5CF6)),
                    title: Text(LanguageService.tr('menu_family_cards'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _showFamilyProfilesDialog();
                    },
                  ),

                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                    child: Text(LanguageService.tr('menu_opd_assistance'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mutedText, letterSpacing: 0.5)),
                  ),

                  ListTile(
                    leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFEF4444)),
                    title: Text(LanguageService.tr('menu_emergency'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _showEmergencyHelplineDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.map_outlined, color: Color(0xFF0077B6)),
                    title: Text(LanguageService.tr('menu_counter_guide'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _showHospitalGuideSheet();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded, color: Color(0xFF059669)),
                    title: Text(LanguageService.tr('menu_help_faq'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _showHelpFaqSheet();
                    },
                  ),

                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                    child: Text(LanguageService.tr('menu_preferences'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.mutedText, letterSpacing: 0.5)),
                  ),

                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: AppTheme.primaryTeal),
                    title: Text(LanguageService.tr('menu_language'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        LanguageService.currentLanguage == 'si'
                            ? '🇱🇰 සිංහල'
                            : LanguageService.currentLanguage == 'ta'
                                ? '🇮🇳 தமிழ்'
                                : '🇬🇧 English',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguageSelectorDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppTheme.darkText),
                    title: Text(LanguageService.tr('menu_settings'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      _showAppSettingsDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppTheme.mutedText),
                    title: Text(LanguageService.tr('menu_app_info'), style: const TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      showAboutDialog(
                        context: context,
                        applicationName: LanguageService.tr('app_title'),
                        applicationVersion: '1.0.0',
                        applicationLegalese: 'Government OPD - Closer to You',
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: Text(
                LanguageService.tr('menu_logout'),
                style: const TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                AuthService.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 12),
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

              Text(
                LanguageService.tr('opd_services'),
                style: const TextStyle(
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
                childAspectRatio: 0.88,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _build3DGlassCard(
                    icon: Icons.confirmation_number_outlined,
                    title: LanguageService.tr('opd_live_queue'),
                    subtitle: LanguageService.tr('opd_live_queue_sub'),
                    gradientColors: [const Color(0xFF0077B6), const Color(0xFF0096C7)],
                    onTap: _openBookAppointment,
                  ),
                  _build3DGlassCard(
                    icon: Icons.event_note_outlined,
                    title: LanguageService.tr('book_appointment'),
                    subtitle: LanguageService.tr('book_appointment_sub'),
                    gradientColors: [const Color(0xFF00A896), const Color(0xFF02C39A)],
                    onTap: _openBookAppointment,
                  ),
                  _build3DGlassCard(
                    icon: Icons.medical_services_outlined,
                    title: LanguageService.tr('medical_records'),
                    subtitle: LanguageService.tr('medical_records_sub'),
                    gradientColors: [const Color(0xFF0284C7), const Color(0xFF38BDF8)],
                    onTap: _openMedicalRecords,
                  ),
                  _build3DGlassCard(
                    icon: Icons.medication_rounded,
                    title: LanguageService.tr('pill_tracker'),
                    subtitle: LanguageService.tr('pill_tracker_sub'),
                    gradientColors: [const Color(0xFF7C3AED), const Color(0xFFA855F7)],
                    onTap: () {
                      Navigator.pushNamed(context, '/pill-tracker');
                    },
                  ),
                  _build3DGlassCard(
                    icon: Icons.psychology_outlined,
                    title: LanguageService.tr('symptom_checker'),
                    subtitle: LanguageService.tr('symptom_checker_sub'),
                    gradientColors: [const Color(0xFFD97706), const Color(0xFFF59E0B)],
                    onTap: () {
                      Navigator.pushNamed(context, '/symptom-checker');
                    },
                  ),
                  _build3DGlassCard(
                    icon: Icons.monitor_weight_outlined,
                    title: LanguageService.tr('health_vitals'),
                    subtitle: LanguageService.tr('health_vitals_sub'),
                    gradientColors: [const Color(0xFFDB2777), const Color(0xFFEC4899)],
                    onTap: () {
                      Navigator.pushNamed(context, '/health-vitals');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  },
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
                  child: ValueListenableBuilder<String?>(
                    valueListenable: AuthService.profilePhotoNotifier,
                    builder: (context, photoPath, _) {
                      final hasPhoto = photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();
                      return CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: hasPhoto
                              ? Image.file(
                                  File(photoPath),
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Text(
                                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ),
                        ),
                      );
                    },
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.mutedText,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
