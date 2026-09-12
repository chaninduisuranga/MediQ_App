import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
import '../core/theme/theme.dart';
import '../widgets/app_bottom_nav_bar.dart';

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
  Map<String, dynamic>? _nextAppointment;

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Notifications State
  List<AppNotification> _notifications = [];

  int get _unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    AuthService.loadSavedProfilePhoto();
    _fetchNextAppointment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchNextAppointment() async {
    final res = await AppointmentService.getMyAppointments();
    if (mounted) {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      setState(() {
        if (res['success'] == true) {
          // Filter out CANCELLED appointments and past dates
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

      final apptDate = DateTime.tryParse(dateStr);
      final todayDate = DateTime.tryParse(todayStr);
      int daysLeft = 0;
      if (apptDate != null && todayDate != null) {
        daysLeft = apptDate.difference(todayDate).inDays;
      }

      if (daysLeft == 0) {
        list.add(AppNotification(
          id: '${id}_today',
          title: '🚨 OPD Appointment Today!',
          message: 'Your $roomName appointment is scheduled for today ($dateStr). Queue Token #$queueNum.',
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
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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

  void _showChooseOPDRoomSheet() {
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.meeting_room_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose OPD Room',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Available rooms & live queue counts for $todayStr',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.1,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildServiceCardItem(
                    icon: Icons.healing_rounded,
                    title: 'Dressing Room',
                    subtitle: 'Wound Care',
                    badgeText: '0 in queue',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBookAppointment();
                    },
                  ),
                  _buildServiceCardItem(
                    icon: Icons.vaccines_rounded,
                    title: 'Injection Room',
                    subtitle: 'IV & IM Care',
                    badgeText: '0 in queue',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBookAppointment();
                    },
                  ),
                  _buildServiceCardItem(
                    icon: Icons.bloodtype_rounded,
                    title: 'Bleeding Room',
                    subtitle: 'Lab Draws',
                    badgeText: '0 in queue',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBookAppointment();
                    },
                  ),
                  _buildServiceCardItem(
                    icon: Icons.pets_rounded,
                    title: 'Animal Bite Room',
                    subtitle: 'ARV Vaccines',
                    badgeText: '0 in queue',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBookAppointment();
                    },
                  ),
                  _buildServiceCardItem(
                    icon: Icons.medical_services_rounded,
                    title: 'OPD Clinic Room',
                    subtitle: 'Consultation',
                    badgeText: '0 in queue',
                    onTap: () {
                      Navigator.pop(ctx);
                      _openBookAppointment();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                Icon(Icons.map_outlined, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 10),
                Text('OPD Hospital Counter Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Floor plan and key counter locations for OPD visitors', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildGuideStep('Counter 1 (Main Lobby)', 'Token generation, patient registration & NIC verification.', Icons.confirmation_number_outlined, const Color(0xFF2563EB)),
                  _buildGuideStep('Room 4 (General OPD)', 'Doctor consultation for fever, cold, body pain & general ailments.', Icons.healing_outlined, const Color(0xFF0284C7)),
                  _buildGuideStep('Room 7 (Dressing Room)', 'Wound cleaning, dressing change, and minor surgical care.', Icons.medical_services_outlined, const Color(0xFFD97706)),
                  _buildGuideStep('Room 2 (Injection Room)', 'Administration of doctor-prescribed IM & IV injection doses.', Icons.vaccines_outlined, const Color(0xFF7C3AED)),
                  _buildGuideStep('Bleeding Room (Lab)', 'Blood sample collection & diagnostic blood draws.', Icons.water_drop_outlined, const Color(0xFFE11D48)),
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
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), height: 1.3)),
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
                backgroundColor: Color(0xFF2563EB),
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(AuthService.currentUser?['full_name'] ?? 'Primary Patient', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Primary Account (Self)', style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
              trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
            ),
            const Divider(),
            const Text('Manage OPD tokens for your family members from a single account.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, color: Color(0xFF2563EB)),
              label: const Text('Add Family Member', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
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
            const Icon(Icons.language_rounded, color: Color(0xFF2563EB)),
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
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)) : null,
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
            const Icon(Icons.settings_outlined, color: Color(0xFF0F172A)),
            const SizedBox(width: 10),
            Text(LanguageService.tr('app_settings'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded, color: Color(0xFF2563EB)),
              title: Text(LanguageService.tr('menu_language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('English / සිංහල / தமிழ்'),
              trailing: Text(
                LanguageService.currentLanguage == 'si'
                    ? 'සිංහල'
                    : LanguageService.currentLanguage == 'ta'
                        ? 'தமிழ்'
                        : 'English',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showLanguageSelectorDialog();
              },
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined, color: Color(0xFF2563EB)),
              title: const Text('Appointment Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: const Text('Receive token SMS & push notifications'),
              value: true,
              activeThumbColor: const Color(0xFF2563EB),
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
                Text('OPD Help & FAQ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                        child: Text('You can book an OPD token directly on MediQ portal or scan your appointment QR code at OPD Counter 1 upon hospital arrival.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('What are the hospital OPD hours?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('OPD counter opens from 7:30 AM to 4:00 PM daily. Emergency triage runs 24/7.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('Is medicine free at OPD pharmacy?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('Yes, all doctor-prescribed medications issued at the government OPD pharmacy are completely free of charge.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          
          // Drawer menu
          drawer: Drawer(
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
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
                                    color: Color(0xFF2563EB),
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
                        leading: const Icon(Icons.smart_toy_outlined, color: Color(0xFF2563EB)),
                        title: const Text('MediQ AI Assistant', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                          child: const Text('AI', style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/ai-chat');
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB)),
                        title: Text(LanguageService.tr('menu_my_profile'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/profile');
                        },
                      ),
                      ListTile(
                        leading: Stack(
                          children: [
                            const Icon(Icons.notifications_none_rounded, color: Color(0xFF2563EB)),
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
                        child: Text(LanguageService.tr('menu_opd_assistance'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
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
                        child: Text(LanguageService.tr('menu_preferences'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                      ),

                      ListTile(
                        leading: const Icon(Icons.language_rounded, color: Color(0xFF2563EB)),
                        title: Text(LanguageService.tr('menu_language'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            LanguageService.currentLanguage == 'si'
                                ? '🇱🇰 සිංහල'
                                : LanguageService.currentLanguage == 'ta'
                                    ? '🇮🇳 தமிழ்'
                                    : '🇬🇧 English',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showLanguageSelectorDialog();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: Color(0xFF0F172A)),
                        title: Text(LanguageService.tr('menu_settings'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _showAppSettingsDialog();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
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

          // Main Body matching the Reference UI
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchNextAppointment,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP ROW: Drawer Icon (left) + Doctor Illustration Avatar (right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Menu Button
                        Builder(
                          builder: (context) {
                            return InkWell(
                              onTap: () => Scaffold.of(context).openDrawer(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.menu_rounded,
                                  size: 26,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          },
                        ),
                        // Right: Notification Bell & Doctor Avatar Accent
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFEF4444), size: 26),
                                  onPressed: _showNotificationsSheet,
                                ),
                                if (_unreadNotificationCount > 0)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            // Doctor Avatar with soft blue background shape
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/profile'),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDBEAFE),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: ValueListenableBuilder<String?>(
                                    valueListenable: AuthService.profilePhotoNotifier,
                                    builder: (context, photoPath, _) {
                                      final hasPhoto = photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();
                                      if (hasPhoto) {
                                        return Image.file(
                                          File(photoPath),
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return Container(
                                        color: const Color(0xFFDBEAFE),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: Color(0xFF2563EB),
                                          size: 26,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // GREETING TEXT
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.25,
                        ),
                        children: [
                          TextSpan(
                            text: "Good Morning,\n",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          TextSpan(text: "Take care of\nyour "),
                          TextSpan(
                            text: "health.",
                            style: TextStyle(color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SEARCH BAR WITH FILTER BUTTON
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: "Search doctors, specialties...",
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Filter button
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
                            onPressed: _showChooseOPDRoomSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // HERO HERO BANNER CARD ("Book Appointment")
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Book Appointment",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Consult with trusted\ndoctors anytime.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDBEAFE),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _openBookAppointment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF1D4ED8),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Book Now",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, size: 14),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Right 3D Banner graphic illustration
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/images/book_appointment.png',
                                width: 75,
                                height: 75,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // OUR SERVICES SECTION (All 6 OPD Modules)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Our Services",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showChooseOPDRoomSheet,
                          child: const Row(
                            children: [
                              Text(
                                "View all",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 6 Services Grid matching Reference UI
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceCardItem(
                            icon: Icons.confirmation_number_outlined,
                            title: "OPD Live Queue",
                            subtitle: "Live token queue",
                            onTap: _showChooseOPDRoomSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildServiceCardItem(
                            icon: Icons.event_note_outlined,
                            title: "Book Appointment",
                            subtitle: "Book doctor slot",
                            onTap: _openBookAppointment,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceCardItem(
                            icon: Icons.medical_services_outlined,
                            title: "Medical Records",
                            subtitle: "Lab & OPD records",
                            onTap: _openMedicalRecords,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildServiceCardItem(
                            icon: Icons.medication_outlined,
                            title: "Pill Tracker",
                            subtitle: "Get your meds",
                            onTap: () => Navigator.pushNamed(context, '/pill-tracker'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceCardItem(
                            icon: Icons.psychology_outlined,
                            title: "Symptom Checker",
                            subtitle: "AI health triage",
                            onTap: () => Navigator.pushNamed(context, '/symptom-checker'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildServiceCardItem(
                            icon: Icons.monitor_weight_outlined,
                            title: "Health Vitals",
                            subtitle: "Full body checkup",
                            onTap: () => Navigator.pushNamed(context, '/health-vitals'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // UPCOMING APPOINTMENT SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Upcoming Appointment",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (_nextAppointment != null)
                          GestureDetector(
                            onTap: _openBookAppointment,
                            child: const Text(
                              "Manage",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Upcoming Appointment Card
                    _buildUpcomingAppointmentCard(),
                    const SizedBox(height: 24),

                    // HEALTH INSIGHTS SECTION
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Health Insights",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/symptom-checker'),
                          child: const Row(
                            children: [
                              Text(
                                "View all",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Health Insight Card matching Reference UI
                    _buildHealthInsightCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Floating AI Chatbot Icon Button (Icon Only)
          floatingActionButton: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/ai-chat'),
                customBorder: const CircleBorder(),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset(
                      'assets/images/chat_bot_icon.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Navigation Bar
          bottomNavigationBar: const AppBottomNavBar(currentIndex: 0),
        );
      },
    );
  }

  // SERVICE CARD ITEM (Soft White Card, Sky Blue Icon Circle, Dark Title)
  Widget _buildServiceCardItem({
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon container with light sky blue background shape
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // UPCOMING APPOINTMENT CARD WIDGET
  Widget _buildUpcomingAppointmentCard() {
    final appt = _nextAppointment;
    final doctorName = appt != null
        ? (appt['doctor_name'] ?? AppointmentService.getRoomDisplayName(appt['room'] ?? ''))
        : "Dr. James Carter";
    final specialty = appt != null
        ? AppointmentService.getRoomDisplayName(appt['room'] ?? '')
        : "Cardiologist";
    final dateStr = appt != null ? (appt['appointment_date'] ?? 'May 24, 2025') : "May 24, 2025";
    final timeStr = appt != null ? "10:30 AM" : "10:30 AM";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Doctor Avatar
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFDBEAFE),
                  shape: BoxShape.circle,
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  child: Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Pill Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "Confirmed",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                timeStr,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // HEALTH INSIGHT CARD WIDGET
  Widget _buildHealthInsightCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/symptom-checker'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "How to maintain a\nhealthy heart",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "5 min read",
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Heart Illustration Image / Graphic
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/health_vitals.png',
                  width: 55,
                  height: 55,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.favorite_rounded,
                    size: 40,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
