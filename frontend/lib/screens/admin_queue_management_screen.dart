import 'package:flutter/material.dart';

import '../core/models/admin_queue_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';
import '../widgets/admin_bottom_nav_bar.dart';

class AdminQueueManagementScreen extends StatefulWidget {
  const AdminQueueManagementScreen({super.key});

  @override
  State<AdminQueueManagementScreen> createState() =>
      _AdminQueueManagementScreenState();
}

class _AdminQueueManagementScreenState
    extends State<AdminQueueManagementScreen> {
  List<AdminQueue> _queues = [];
  List<AdminQueueAlert> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadQueues();
  }

  Future<void> _loadQueues() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result =
        await AdminService.getQueues(date: _formatDate(_selectedDate));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _queues = result['queues'] as List<AdminQueue>;
        _alerts = result['alerts'] as List<AdminQueueAlert>;
      } else {
        _errorMessage = result['message'] as String?;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    _loadQueues();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.queue_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(child: Text('Queue Management')),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadQueues,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh queues',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQueues,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildIntroBanner(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _queueHeading,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(_formatDate(_selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildMessage(_errorMessage!, Icons.error_outline_rounded)
            else ...[
              if (_alerts.isNotEmpty) ...[
                ..._alerts.map(_buildAlert),
                const SizedBox(height: 8),
              ],
              if (_queues.isEmpty)
                _buildMessage('No queue data available.', Icons.queue_rounded)
              else
                ..._queues.map(_buildQueueCard),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        children: [
          _QueueBannerIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OPD queue overview',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Monitor waiting patients and congestion alerts',
                    style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(AdminQueue queue) {
    final color = _statusColor(queue.congestionStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFBAE6FD).withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    queue.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(queue.congestionStatus, color),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0F2FE)),
              ),
              child: Row(
                children: [
                  _metric('Waiting', '${queue.waiting}', Colors.orange),
                  _metric('Serving', '${queue.serving}', AppTheme.primaryBlue),
                  _metric('Completed', '${queue.completed}', Colors.green),
                  _metric('Avg wait', '${queue.averageWaitMinutes}m', color),
                ],
              ),
            ),
            if (queue.congestionStatus != 'NORMAL') ...[
              const SizedBox(height: 14),
              Text(
                queue.recommendedAction,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlert(AdminQueueAlert alert) {
    final color = _statusColor(alert.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 8),
              Text('QUEUE ALERT',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(alert.queueName,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Waiting: ${alert.waiting} patients  •  Average wait: ${alert.averageWaitMinutes} min',
            style: const TextStyle(color: AppTheme.darkText),
          ),
          const SizedBox(height: 8),
          Text('Status: ${alert.status}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Recommended action: ${alert.recommendedAction}',
              style: const TextStyle(color: AppTheme.mutedText, height: 1.3)),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppTheme.mutedText)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Chip(
      label: Text(status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildMessage(String message, IconData icon) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppTheme.mutedText),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      );

  Color _statusColor(String status) {
    switch (status) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String get _queueHeading {
    final today = DateTime.now();
    final isToday = _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
    return isToday
        ? 'TODAY\'S QUEUES'
        : 'QUEUES FOR ${_formatDate(_selectedDate)}';
  }
}

class _QueueBannerIcon extends StatelessWidget {
  const _QueueBannerIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: const Icon(Icons.queue_rounded, color: Colors.white, size: 25),
    );
  }
}
