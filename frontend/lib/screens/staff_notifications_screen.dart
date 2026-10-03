import 'package:flutter/material.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class StaffAlert {
  final String id;
  final String title;
  final String message;
  final String type; // 'QUEUE', 'PRIORITY', 'DELAY', 'ANNOUNCEMENT'
  final DateTime timestamp;
  bool isRead;

  StaffAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

class StaffNotificationsScreen extends StatefulWidget {
  const StaffNotificationsScreen({super.key});

  @override
  State<StaffNotificationsScreen> createState() =>
      _StaffNotificationsScreenState();
}

class _StaffNotificationsScreenState extends State<StaffNotificationsScreen> {
  String _selectedFilter = 'ALL';

  final List<StaffAlert> _alerts = [
    StaffAlert(
      id: '1',
      title: 'Priority Patient Check-In',
      message:
          'Priority Patient Anu Perera (Token #G-021, Elderly) has arrived at General OPD.',
      type: 'PRIORITY',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
    ),
    StaffAlert(
      id: '2',
      title: 'High Queue Volume Alert',
      message:
          'General OPD waiting queue has exceeded 20 patients. Batch doctor allocation recommended.',
      type: 'QUEUE',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      isRead: false,
    ),
    StaffAlert(
      id: '3',
      title: 'Doctor Shift Update',
      message:
          'Dr. Suneth Perera is currently available and on-duty in General OPD — Room 01.',
      type: 'ANNOUNCEMENT',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
    ),
    StaffAlert(
      id: '4',
      title: 'Dressing Room Brief Delay',
      message:
          'Dressing Room sterilization in progress. Estimated 10-minute queue pause.',
      type: 'DELAY',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
    ),
    StaffAlert(
      id: '5',
      title: 'System Announcement',
      message:
          'Daily OPD roster hand-over meeting at 03:45 PM in Central Clinical Station.',
      type: 'ANNOUNCEMENT',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      isRead: true,
    ),
  ];

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  List<StaffAlert> get _filteredAlerts {
    if (_selectedFilter == 'ALL') return _alerts;
    return _alerts.where((a) => a.type == _selectedFilter).toList();
  }

  void _markAllAsRead() {
    setState(() {
      for (final a in _alerts) {
        a.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All alerts marked as read.'),
        backgroundColor: AppTheme.primarySkyBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.staffNotifications),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded,
                  size: 16, color: AppTheme.primarySkyBlue),
              label: const Text(
                'Mark All Read',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primarySkyBlue,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 4),
      body: Column(
        children: [
          // Filter Chips Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Alerts (${_alerts.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PRIORITY', 'Priority'),
                  const SizedBox(width: 8),
                  _buildFilterChip('QUEUE', 'Queue Alerts'),
                  const SizedBox(width: 8),
                  _buildFilterChip('DELAY', 'Delays'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ANNOUNCEMENT', 'Announcements'),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Alerts List
          Expanded(
            child: _filteredAlerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No alerts found in this category.',
                          style: TextStyle(
                              color: AppTheme.mutedText, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                      setState(() {});
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAlerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final alert = _filteredAlerts[index];
                        return _buildAlertCard(alert);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primarySkyBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.darkText,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildAlertCard(StaffAlert alert) {
    Color typeColor;
    IconData typeIcon;

    switch (alert.type) {
      case 'PRIORITY':
        typeColor = AppTheme.errorRed;
        typeIcon = Icons.priority_high_rounded;
        break;
      case 'QUEUE':
        typeColor = const Color(0xFF0284C7);
        typeIcon = Icons.format_list_numbered_rounded;
        break;
      case 'DELAY':
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.timer_off_outlined;
        break;
      default:
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.campaign_rounded;
    }

    final timeAgo = _formatTimeAgo(alert.timestamp);

    return InkWell(
      onTap: () {
        setState(() => alert.isRead = true);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: alert.isRead ? Colors.white : const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: alert.isRead
                ? Colors.grey.shade200
                : AppTheme.primarySkyBlue.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
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
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, color: typeColor, size: 20),
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
                          alert.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: alert.isRead
                                ? AppTheme.darkText
                                : AppTheme.primarySkyBlue,
                          ),
                        ),
                      ),
                      if (!alert.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primarySkyBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.darkText,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeAgo,
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

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
