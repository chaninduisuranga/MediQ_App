import 'package:flutter/material.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class StaffAlert {
  final int id;
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

  factory StaffAlert.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['id']?.toString() ?? '');
    final timestamp = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (id == null || timestamp == null) {
      throw const FormatException(
          'Staff notification has an invalid ID or timestamp.');
    }
    return StaffAlert(
      id: id,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      type: (json['type']?.toString() ?? '').toUpperCase(),
      timestamp: timestamp,
      isRead: json['is_read'] == true,
    );
  }
}

class StaffNotificationsScreen extends StatefulWidget {
  const StaffNotificationsScreen({super.key});

  @override
  State<StaffNotificationsScreen> createState() =>
      _StaffNotificationsScreenState();
}

class _StaffNotificationsScreenState extends State<StaffNotificationsScreen> {
  String _selectedFilter = 'ALL';
  final List<StaffAlert> _alerts = [];
  final Set<int> _updatingAlertIds = {};
  bool _isLoading = true;
  bool _isMarkingAllRead = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  int get _unreadCount => _alerts.where((a) => !a.isRead).length;

  List<StaffAlert> get _filteredAlerts {
    if (_selectedFilter == 'ALL') return _alerts;
    return _alerts.where((a) => a.type == _selectedFilter).toList();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await QueueService.getStaffNotifications();
      final alerts = response.map(StaffAlert.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _alerts
          ..clear()
          ..addAll(alerts);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _markAsRead(StaffAlert alert) async {
    if (alert.isRead || _updatingAlertIds.contains(alert.id)) return;
    setState(() => _updatingAlertIds.add(alert.id));
    try {
      await QueueService.markStaffNotificationRead(alert.id);
      if (!mounted) return;
      setState(() {
        alert.isRead = true;
        _updatingAlertIds.remove(alert.id);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingAlertIds.remove(alert.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark notification as read: $error')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0 || _isMarkingAllRead) return;
    setState(() => _isMarkingAllRead = true);
    try {
      await QueueService.markAllStaffNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final alert in _alerts) {
          alert.isRead = true;
        }
        _isMarkingAllRead = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All alerts marked as read.'),
          backgroundColor: AppTheme.primarySkyBlue,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMarkingAllRead = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark all alerts as read: $error')),
      );
    }
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
              onPressed: _isMarkingAllRead ? null : _markAllAsRead,
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
                  const SizedBox(width: 8),
                  _buildFilterChip('DOCTOR', 'Doctor'),
                  const SizedBox(width: 8),
                  _buildFilterChip('ALLOCATION', 'Allocation'),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Alerts List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _buildAlertsContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsContent() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primarySkyBlue),
            ),
          ),
        ],
      );
    }

    if (_loadError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppTheme.errorRed),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load notifications.',
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadNotifications,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_filteredAlerts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'No alerts found in this category.',
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAlerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildAlertCard(_filteredAlerts[index]),
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
      case 'DOCTOR':
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.medical_services_outlined;
        break;
      case 'ALLOCATION':
        typeColor = const Color(0xFF059669);
        typeIcon = Icons.assignment_turned_in_outlined;
        break;
      case 'CLOSURE':
        typeColor = AppTheme.errorRed;
        typeIcon = Icons.block_outlined;
        break;
      default:
        typeColor = const Color(0xFF8B5CF6);
        typeIcon = Icons.campaign_rounded;
    }

    final timeAgo = _formatTimeAgo(alert.timestamp);

    return InkWell(
      onTap: alert.isRead || _updatingAlertIds.contains(alert.id)
          ? null
          : () => _markAsRead(alert),
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
