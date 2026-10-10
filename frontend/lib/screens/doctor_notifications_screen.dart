import 'package:flutter/material.dart';
import '../core/services/doctor_service.dart';
import '../core/theme/theme.dart';

class DoctorNotificationsScreen extends StatefulWidget {
  const DoctorNotificationsScreen({super.key});

  @override
  State<DoctorNotificationsScreen> createState() =>
      _DoctorNotificationsScreenState();
}

class _DoctorNotificationsScreenState
    extends State<DoctorNotificationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final list = await DoctorService.getNotifications();
    if (mounted) setState(() { _notifications = list; _isLoading = false; });
  }

  Future<void> _markAsRead(int id) async {
    await DoctorService.markNotificationRead(id);
    _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.doctorPrimaryColor))
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, i) =>
                        _buildNotificationCard(_notifications[i]),
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = notif['is_read'] == true;
    final id = (notif['id'] as int?) ?? 0;
    
    IconData iconData;
    Color iconColor;
    
    switch (notif['type']) {
      case 'NEW_APPOINTMENT':
        iconData = Icons.event_available_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case 'APPOINTMENT_CANCELLED':
        iconData = Icons.event_busy_rounded;
        iconColor = AppTheme.errorRed;
        break;
      case 'QUEUE_UPDATE':
        iconData = Icons.format_list_numbered_rounded;
        iconColor = const Color(0xFFF59E0B);
        break;
      case 'ADMIN_ANNOUNCEMENT':
        iconData = Icons.campaign_rounded;
        iconColor = AppTheme.doctorPrimaryColor;
        break;
      default:
        iconData = Icons.notifications_rounded;
        iconColor = AppTheme.mutedText;
    }

    String timeStr = notif['timestamp'] ?? '';
    try {
      final dt = DateTime.parse(timeStr);
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      timeStr = '${months[dt.month - 1]} ${dt.day}, ${dt.year} · ${hour.toString().padLeft(2, '0')}:$min $period';
    } catch (_) {}

    return GestureDetector(
      onTap: isRead ? null : () => _markAsRead(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppTheme.doctorPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isRead ? Colors.grey.shade200 : AppTheme.doctorPrimaryColor.withValues(alpha: 0.3)),
          boxShadow: isRead ? [] : [
            BoxShadow(
              color: AppTheme.doctorPrimaryColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif['title'] ?? 'Notification',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.doctorPrimaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif['message'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: isRead ? AppTheme.mutedText : AppTheme.darkText.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w500,
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded,
              size: 64, color: AppTheme.mutedText.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'No notifications right now',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}
