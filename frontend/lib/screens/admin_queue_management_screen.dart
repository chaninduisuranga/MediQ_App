import 'package:flutter/material.dart';

import '../core/models/admin_queue_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';

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
        title: const Text('Queue Management'),
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
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'TODAY\'S QUEUES',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildQueueCard(AdminQueue queue) {
    final color = _statusColor(queue.congestionStatus);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _statusBadge(queue.congestionStatus, color),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _metric('Waiting', '${queue.waiting}', Colors.orange),
                _metric('Serving', '${queue.serving}', AppTheme.primaryBlue),
                _metric('Completed', '${queue.completed}', Colors.green),
                _metric('Avg wait', '${queue.averageWaitMinutes}m', color),
              ],
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
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
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
              'Waiting: ${alert.waiting} patients  •  Average wait: ${alert.averageWaitMinutes} min'),
          const SizedBox(height: 8),
          Text('Status: ${alert.status}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Recommended action: ${alert.recommendedAction}'),
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
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
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
}
