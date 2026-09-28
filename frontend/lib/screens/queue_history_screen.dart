import 'package:flutter/material.dart';
import '../core/services/appointment_service.dart';
import '../core/services/queue_service.dart';
import '../core/theme/theme.dart';
import '../routes/routes.dart';
import '../widgets/staff_bottom_nav_bar.dart';
import '../widgets/staff_drawer.dart';

class QueueHistoryScreen extends StatefulWidget {
  const QueueHistoryScreen({super.key});

  @override
  State<QueueHistoryScreen> createState() => _QueueHistoryScreenState();
}

class _QueueHistoryScreenState extends State<QueueHistoryScreen> {
  String _selectedFilterTime = 'Today';
  String _selectedRoomFilter = 'ALL';
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final list = await QueueService.getQueueHistory(
      filterTime: _selectedFilterTime,
      roomKey: _selectedRoomFilter,
    );
    if (mounted) {
      setState(() {
        _historyList = list;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'IN_PROGRESS':
        return Colors.orange.shade800;
      case 'SKIPPED':
        return Colors.grey.shade600;
      case 'CHECKED_IN':
        return AppTheme.primarySkyBlue;
      case 'PRIORITY':
        return AppTheme.errorRed;
      default:
        return AppTheme.mutedText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const StaffDrawer(currentRoute: AppRoutes.queueHistory),
      appBar: AppBar(
        title: const Text(
          'Queue Activity History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Time Range Segment Chips
                Row(
                  children: ['Today', 'This Week', 'This Month'].map((time) {
                    final isSelected = _selectedFilterTime == time;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(time),
                        selected: isSelected,
                        selectedColor: AppTheme.primarySkyBlue,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.darkText,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedFilterTime = time);
                            _fetchHistory();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 8),

                // Room Filter Dropdown
                Row(
                  children: [
                    const Text('Room Filter: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRoomFilter,
                            isExpanded: true,
                            style: const TextStyle(fontSize: 13, color: AppTheme.darkText),
                            items: [
                              const DropdownMenuItem(value: 'ALL', child: Text('All OPD Rooms')),
                              ...AppointmentService.opdRooms.map((r) {
                                return DropdownMenuItem<String>(
                                  value: r['key'] as String,
                                  child: Text(r['name'] as String),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRoomFilter = val);
                                _fetchHistory();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // History Log List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primarySkyBlue))
                : (_historyList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No Queue History Recorded',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Actions performed on queue tokens will appear here.',
                              style: TextStyle(fontSize: 13, color: AppTheme.mutedText),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _historyList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _historyList[index];
                          final status = item['status'] as String? ?? 'COMPLETED';
                          final statusColor = _getStatusColor(status);
                          final roomName = AppointmentService.getRoomDisplayName(item['room'] ?? '');

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        item['token'] ?? 'N/A',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['patient_name'] ?? 'Patient',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.darkText),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Action: ${item['action']} | $roomName',
                                        style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                                      ),
                                      if ((item['details'] ?? '').toString().isNotEmpty)
                                        Text(
                                          '${item['details']}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item['timestamp'] ?? '',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                                    ),
                                    Text(
                                      item['date'] ?? '',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.mutedText),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
      bottomNavigationBar: const StaffBottomNavBar(currentIndex: 1),
    );
  }
}
