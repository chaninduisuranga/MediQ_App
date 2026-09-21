import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  List<dynamic> _allUpcomingAppointments = [];

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Hero Banner Carousel State
  late final PageController _bannerPageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  // Notifications State
  List<AppNotification> _notifications = [];

  int get _unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController();
    _startBannerAutoSlide();
    AuthService.loadSavedProfilePhoto();
    _fetchNextAppointment();
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerPageController.hasClients) {
        final nextPage = (_currentBannerIndex + 1) % 4;
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
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
            _allUpcomingAppointments = activeList;
          } else {
            _allUpcomingAppointments = [];
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
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          
          // Ultra-Modern Glassmorphic Navigation Drawer
          drawer: Drawer(
            backgroundColor: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                // 1. Ultra-Modern Glassmorphic Header Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 24,
                    left: 20,
                    right: 20,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x331E3A8A),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 3D Avatar Ring with Glow
                          ValueListenableBuilder<String?>(
                            valueListenable: AuthService.profilePhotoNotifier,
                            builder: (context, photoPath, _) {
                              final hasPhoto = photoPath != null && photoPath.isNotEmpty && File(photoPath).existsSync();
                              return Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: hasPhoto
                                        ? Image.file(
                                            File(photoPath),
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                          )
                                        : Text(
                                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E3A8A),
                                            ),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF4ADE80),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'NIC: $nic',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (phone != 'N/A' && phone.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    '📱 $phone',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Scrollable Glass Menu Categories
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    children: [
                      // --- CORE SERVICES CATEGORY ---
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 8, bottom: 8),
                        child: Text(
                          'CORE SERVICES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      
                      // AI Assistant
                      _buildModernDrawerTile(
                        icon: Icons.smart_toy_rounded,
                        iconGradientColors: [const Color(0xFF6366F1), const Color(0xFFA855F7)],
                        title: 'MediQ AI Assistant',
                        titleColor: const Color(0xFF4F46E5),
                        badge: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF818CF8), Color(0xFFC084FC)]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF818CF8).withValues(alpha: 0.4), blurRadius: 6),
                            ],
                          ),
                          child: const Text('✨ AI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/ai-chat');
                        },
                      ),

                      // My Profile
                      _buildModernDrawerTile(
                        icon: Icons.person_rounded,
                        iconGradientColors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
                        title: LanguageService.tr('menu_my_profile'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/profile');
                        },
                      ),

                      // Notifications
                      _buildModernDrawerTile(
                        icon: Icons.notifications_rounded,
                        iconGradientColors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
                        title: LanguageService.tr('menu_notifications'),
                        badge: _unreadNotificationCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorRed,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.errorRed.withValues(alpha: 0.4), blurRadius: 6),
                                  ],
                                ),
                                child: Text(
                                  '$_unreadNotificationCount',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _showNotificationsSheet();
                        },
                      ),

                      // Family Profiles
                      _buildModernDrawerTile(
                        icon: Icons.family_restroom_rounded,
                        iconGradientColors: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
                        title: LanguageService.tr('menu_family_cards'),
                        onTap: () {
                          Navigator.pop(context);
                          _showFamilyProfilesDialog();
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // --- OPD ASSISTANCE CATEGORY ---
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 4, bottom: 8),
                        child: Text(
                          'OPD ASSISTANCE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      // Hospital Guide
                      _buildModernDrawerTile(
                        icon: Icons.map_rounded,
                        iconGradientColors: [const Color(0xFF0EA5E9), const Color(0xFF38BDF8)],
                        title: LanguageService.tr('menu_counter_guide'),
                        onTap: () {
                          Navigator.pop(context);
                          _showHospitalGuideSheet();
                        },
                      ),

                      // Help & FAQ
                      _buildModernDrawerTile(
                        icon: Icons.help_center_rounded,
                        iconGradientColors: [const Color(0xFF10B981), const Color(0xFF34D399)],
                        title: LanguageService.tr('menu_help_faq'),
                        onTap: () {
                          Navigator.pop(context);
                          _showHelpFaqSheet();
                        },
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),

                      // --- PREFERENCES CATEGORY ---
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 4, bottom: 8),
                        child: Text(
                          'PREFERENCES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      // Language Selector
                      _buildModernDrawerTile(
                        icon: Icons.language_rounded,
                        iconGradientColors: [const Color(0xFF2563EB), const Color(0xFF60A5FA)],
                        title: LanguageService.tr('menu_language'),
                        badge: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
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

                      // App Settings
                      _buildModernDrawerTile(
                        icon: Icons.settings_rounded,
                        iconGradientColors: [const Color(0xFF64748B), const Color(0xFF94A3B8)],
                        title: LanguageService.tr('menu_settings'),
                        onTap: () {
                          Navigator.pop(context);
                          _showAppSettingsDialog();
                        },
                      ),

                      // App Info
                      _buildModernDrawerTile(
                        icon: Icons.info_rounded,
                        iconGradientColors: [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
                        title: LanguageService.tr('menu_app_info'),
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

                      const SizedBox(height: 12),

                      // 3. Emergency Suwa Seriya Quick Call Card
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showEmergencyHelplineDialog();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Emergency Hotline 1990',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                    ),
                                    Text(
                                      '1990 Suwa Seriya Ambulance',
                                      style: TextStyle(fontSize: 10, color: Color(0xFFB91C1C)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFEF4444), size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Modern Red-Tinted Glass Logout Footer Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        AuthService.performLogout(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: AppTheme.errorRed, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              LanguageService.tr('menu_logout'),
                              style: const TextStyle(
                                color: AppTheme.errorRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // HERO BANNER CAROUSEL SLIDESHOW
                    Column(
                      children: [
                        SizedBox(
                          height: 205,
                          child: PageView(
                            controller: _bannerPageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentBannerIndex = index;
                              });
                            },
                            children: [
                              // 1. Book Appointment Card (Navy to Ocean Blue)
                              _buildHeroBannerCard(
                                badgeText: "INSTANT OPD TOKEN",
                                title: "Book Appointment",
                                subtitle: "Consult with trusted OPD doctors without waiting in long queues.",
                                buttonText: "Book Now",
                                gradientColors: const [
                                  Color(0xFF0F172A),
                                  Color(0xFF1E3A8A),
                                  Color(0xFF0284C7),
                                ],
                                glowColor: const Color(0xFF0284C7),
                                ambientTopColor: const Color(0xFF38BDF8),
                                ambientBottomColor: const Color(0xFF0D9488),
                                iconData: Icons.calendar_month_rounded,
                                imagePath: 'assets/images/book_appointment.png',
                                onTap: _openBookAppointment,
                              ),
                              // 2. OPD Live Queue Card (Sapphire to Royal Blue)
                              _buildHeroBannerCard(
                                badgeText: "LIVE QUEUE TRACKER",
                                title: "OPD Live Queue",
                                subtitle: "Track your token queue number live & stay updated on your wait time.",
                                buttonText: "Check Queue",
                                gradientColors: const [
                                  Color(0xFF0B192C),
                                  Color(0xFF1E40AF),
                                  Color(0xFF2563EB),
                                ],
                                glowColor: const Color(0xFF2563EB),
                                ambientTopColor: const Color(0xFF60A5FA),
                                ambientBottomColor: const Color(0xFF1D4ED8),
                                iconData: Icons.confirmation_number_rounded,
                                imagePath: 'assets/images/opd_live_queue.png',
                                onTap: _showChooseOPDRoomSheet,
                              ),
                              // 3. Medical Records Card (Deep Ocean to Cerulean Blue)
                              _buildHeroBannerCard(
                                badgeText: "DIGITAL HEALTH RECORD",
                                title: "Medical Records",
                                subtitle: "Store & access all your lab reports, prescriptions & doctor notes securely.",
                                buttonText: "View Records",
                                gradientColors: const [
                                  Color(0xFF0F2C3A),
                                  Color(0xFF0369A1),
                                  Color(0xFF0891B2),
                                ],
                                glowColor: const Color(0xFF0891B2),
                                ambientTopColor: const Color(0xFF22D3EE),
                                ambientBottomColor: const Color(0xFF0284C7),
                                iconData: Icons.folder_shared_rounded,
                                imagePath: 'assets/images/medical_records.png',
                                onTap: _openMedicalRecords,
                              ),
                              // 4. Pill & Vitals Tracker Card (Midnight Blue to Electric Sky Blue)
                              _buildHeroBannerCard(
                                badgeText: "DAILY VITALS & PILLS",
                                title: "Pills & Vitals Tracker",
                                subtitle: "Set medicine pill timings, check your BMI & track blood sugar levels easily.",
                                buttonText: "Track Health",
                                gradientColors: const [
                                  Color(0xFF172554),
                                  Color(0xFF1D4ED8),
                                  Color(0xFF38BDF8),
                                ],
                                glowColor: const Color(0xFF38BDF8),
                                ambientTopColor: const Color(0xFF7DD3FC),
                                ambientBottomColor: const Color(0xFF2563EB),
                                iconData: Icons.favorite_rounded,
                                imagePath: 'assets/images/pill_tracker.png',
                                onTap: () => Navigator.pushNamed(context, '/health-vitals'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Sleek Page Indicator Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final isActive = _currentBannerIndex == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 22 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // OUR SERVICES SECTION (All 6 OPD Modules)
                    const Text(
                      "Our Services",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 6 Services Grid matching Reference UI with Cohesive MediQ Blue Theme Tints
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceCardItem(
                            imagePath: 'assets/images/opd_live_queue.png',
                            icon: Icons.confirmation_number_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBgColor: const Color(0xFFEFF6FF),
                            title: "OPD Live Queue",
                            subtitle: "Live token queue",
                            onTap: _showChooseOPDRoomSheet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildServiceCardItem(
                            imagePath: 'assets/images/book_appointment.png',
                            icon: Icons.event_available_rounded,
                            iconColor: const Color(0xFF1D4ED8),
                            iconBgColor: const Color(0xFFDBEAFE),
                            title: "Book Appointment",
                            subtitle: "Book doctor slot",
                            onTap: _openBookAppointment,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceCardItem(
                            imagePath: 'assets/images/medical_records.png',
                            icon: Icons.folder_shared_rounded,
                            iconColor: const Color(0xFF0284C7),
                            iconBgColor: const Color(0xFFF0F9FF),
                            title: "Medical Records",
                            subtitle: "Lab & OPD records",
                            onTap: _openMedicalRecords,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildServiceCardItem(
                            imagePath: 'assets/images/pill_tracker.png',
                            icon: Icons.medication_rounded,
                            iconColor: const Color(0xFF0891B2),
                            iconBgColor: const Color(0xFFECFEFF),
                            title: "Pill Tracker",
                            subtitle: "Get your meds",
                            onTap: () => Navigator.pushNamed(context, '/pill-tracker'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildServiceCardItem(
                            imagePath: 'assets/images/symptom_checker.png',
                            icon: Icons.psychology_rounded,
                            iconColor: const Color(0xFF4F46E5),
                            iconBgColor: const Color(0xFFEEF2FF),
                            title: "Symptom Checker",
                            subtitle: "AI health triage",
                            onTap: () => Navigator.pushNamed(context, '/symptom-checker'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildServiceCardItem(
                            imagePath: 'assets/images/health_vitals.png',
                            icon: Icons.monitor_weight_rounded,
                            iconColor: const Color(0xFF2563EB),
                            iconBgColor: const Color(0xFFEFF6FF),
                            title: "Health Vitals",
                            subtitle: "Full body checkup",
                            onTap: () => Navigator.pushNamed(context, '/health-vitals'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // UPCOMING APPOINTMENT SECTION
                    const Text(
                      "Upcoming Appointments",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Display all appointments one by one ordered by date
                    if (_allUpcomingAppointments.isEmpty)
                      _buildEmptyAppointmentCard()
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _allUpcomingAppointments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final appt = _allUpcomingAppointments[index] as Map<String, dynamic>;
                          return _buildUpcomingAppointmentCard(appt, todayStr);
                        },
                      ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 12),
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

  // HERO BANNER CARD (3D Glassmorphic Design)
  Widget _buildHeroBannerCard({
    required String badgeText,
    required String title,
    required String subtitle,
    required String buttonText,
    required List<Color> gradientColors,
    required Color glowColor,
    required Color ambientTopColor,
    required Color ambientBottomColor,
    required IconData iconData,
    String? imagePath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 22,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Background Ambient Decorative Glows
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ambientTopColor.withValues(alpha: 0.25),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ambientBottomColor.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Foreground Banner Content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Badge Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stars_rounded,
                                color: ambientTopColor,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),

                        // Action Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                buttonText,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: gradientColors.length > 1 ? gradientColors[1] : gradientColors[0],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: gradientColors.length > 1 ? gradientColors[1] : gradientColors[0],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Right 3D Medical Graphic with Glowing Glass Sphere
                  Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ambientTopColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: imagePath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(45),
                              child: Image.asset(
                                imagePath,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  iconData,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              iconData,
                              size: 46,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SERVICE CARD ITEM (Compact White Card, Full-Width Header Graphic Badge, Bold Titles)
  Widget _buildServiceCardItem({
    IconData? icon,
    String? imagePath,
    required String title,
    required String subtitle,
    Color iconColor = const Color(0xFF2563EB),
    Color iconBgColor = const Color(0xFFEFF6FF),
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.08),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // Icon or Image badge container matching full width of card
            Container(
              width: double.infinity,
              height: imagePath != null ? 65 : 52,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.2),
                  width: 1.2,
                ),
                boxShadow: [
                  if (imagePath != null)
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Center(
                child: imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          imagePath,
                          width: double.infinity,
                          height: 65,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            icon ?? Icons.confirmation_number_rounded,
                            color: iconColor,
                            size: 26,
                          ),
                        ),
                      )
                    : Icon(
                        icon ?? Icons.confirmation_number_rounded,
                        color: iconColor,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
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

  String _formatDisplayDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = days[dt.weekday - 1];
      final monthName = months[dt.month - 1];
      return '$dayName, $monthName ${dt.day}, ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  IconData _getRoomIcon(String roomKey) {
    switch (roomKey) {
      case 'DRESSING_ROOM':
        return Icons.healing_rounded;
      case 'INJECTION_ROOM':
        return Icons.vaccines_rounded;
      case 'BLEEDING_ROOM':
        return Icons.water_drop_rounded;
      case 'ANIMAL_BITE_ROOM':
        return Icons.pets_rounded;
      case 'OPD_CLINIC_ROOM':
        return Icons.medical_services_rounded;
      default:
        return Icons.meeting_room_rounded;
    }
  }

  void _showAppointmentQrModal(Map<String, dynamic> appt) {
    final roomKey = appt['room'] as String? ?? '';
    final roomName = AppointmentService.getRoomDisplayName(roomKey);
    final roomColorInt = AppointmentService.getRoomColor(roomKey);
    final roomColor = Color(roomColorInt);
    final queueNum = appt['queue_number'] ?? 0;
    final dateStr = appt['appointment_date'] as String? ?? '';
    final formattedDate = _formatDisplayDate(dateStr);
    final qrData = (appt['qr_code_data'] as String? ?? '').isNotEmpty
        ? appt['qr_code_data'] as String
        : 'http://mediq.app/appointment/${appt['id']}';
    final user = AuthService.currentUser ?? {};
    final patientName = user['full_name'] ?? appt['patient_name'] ?? 'Patient';
    final patientNic = user['nic'] ?? appt['patient_nic'] ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: roomColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getRoomIcon(roomKey), color: roomColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Token #$queueNum • $formattedDate',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: roomColor.withValues(alpha: 0.3), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: roomColor.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: roomColor,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scan this QR code at OPD Counter 1',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: roomColor),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildModalDetailRow('Patient Name', patientName),
                          const Divider(height: 16),
                          _buildModalDetailRow('NIC Number', patientNic),
                          const Divider(height: 16),
                          _buildModalDetailRow('OPD Room', roomName),
                          const Divider(height: 16),
                          _buildModalDetailRow('Queue Token', '#$queueNum'),
                          const Divider(height: 16),
                          _buildModalDetailRow('Appointment Date', formattedDate),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildUpcomingAppointmentCard(Map<String, dynamic> appt, String todayStr) {
    final roomKey = appt['room'] as String? ?? '';
    final roomName = AppointmentService.getRoomDisplayName(roomKey);
    final roomColorInt = AppointmentService.getRoomColor(roomKey);
    final roomColor = Color(roomColorInt);
    final queueNum = appt['queue_number'] ?? 0;
    final dateStr = appt['appointment_date'] as String? ?? '';
    final formattedDate = _formatDisplayDate(dateStr);
    final isToday = (dateStr == todayStr);

    final qrData = (appt['qr_code_data'] as String? ?? '').isNotEmpty
        ? appt['qr_code_data'] as String
        : 'http://mediq.app/appointment/${appt['id']}';

    return GestureDetector(
      onTap: () => _showAppointmentQrModal(appt),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isToday ? const Color(0xFFFFFBEB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isToday ? const Color(0xFFF59E0B) : const Color(0xFFF1F5F9),
            width: isToday ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isToday
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.22)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isToday ? 14 : 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Room Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: roomColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_getRoomIcon(roomKey), color: roomColor, size: 24),
            ),
            const SizedBox(width: 12),

            // Middle Room & Date & Token details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          roomName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 2),
                              Text(
                                "TODAY",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "Confirmed",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roomColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Token #$queueNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: roomColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Right Mini QR Code
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isToday ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 52,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: roomColor,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyAppointmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded, size: 28, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 10),
          const Text(
            "No Upcoming Appointments",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            "Book an OPD token to get your appointment queue number.",
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                elevation: 2,
                shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              ),
              onPressed: _openBookAppointment,
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: const Text(
                'Book Appointment Now',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDrawerTile({
    required IconData icon,
    required List<Color> iconGradientColors,
    required String title,
    Color? titleColor,
    Widget? badge,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iconGradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradientColors.first.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
