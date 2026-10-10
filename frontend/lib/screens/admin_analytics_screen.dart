import 'package:flutter/material.dart';

import '../core/models/admin_analytics_model.dart';
import '../core/services/admin_service.dart';
import '../core/theme/theme.dart';
import '../core/utils/duration_format.dart';
import '../widgets/admin_bottom_nav_bar.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  static const _periods = <String, String>{
    '7d': '7 days',
    '30d': '30 days',
    '90d': '90 days',
  };

  String _period = '30d';
  AdminAnalytics? _analytics;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await AdminService.getAnalytics(period: _period);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _analytics = result['analytics'] as AdminAnalytics;
      } else {
        _errorMessage = result['message'] as String?;
      }
    });
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
              child: const Icon(Icons.analytics_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Flexible(child: Text('Analytics')),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh analytics',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 12),
            if (_analytics != null)
              Text(
                '${_analytics!.startDate}  to  ${_analytics!.endDate}',
                style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
              ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildMessage(_errorMessage!, Icons.error_outline_rounded)
            else if (_analytics == null)
              _buildMessage(
                  'No analytics data available.', Icons.analytics_outlined)
            else ...[
              _buildAppointmentSummary(_analytics!),
              const SizedBox(height: 24),
              _buildSectionHeader('Queue performance', Icons.queue_rounded),
              const SizedBox(height: 4),
              const Text(
                'Wait is measured from the appointment slot to service start. Congestion days exceed 20 waiting patients.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 11),
              ),
              const SizedBox(height: 10),
              _buildQueuePerformance(_analytics!.queueServices),
              const SizedBox(height: 24),
              _buildSectionHeader(
                  'Appointment outcomes', Icons.event_note_rounded),
              const SizedBox(height: 4),
              const Text(
                'Each bar shows completed, cancelled, missed, and other bookings.',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 10),
              _buildAppointmentTrend(_analytics!.trend),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const AdminBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildPeriodSelector() {
    return SegmentedButton<String>(
      segments: _periods.entries
          .map((entry) => ButtonSegment<String>(
                value: entry.key,
                label: Text(entry.value),
              ))
          .toList(),
      selected: {_period},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() => _period = selection.first);
        _loadAnalytics();
      },
    );
  }

  Widget _buildAppointmentSummary(AdminAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Appointments', Icons.calendar_month_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _summaryMetric(
                    'Bookings', analytics.bookings, AppTheme.primaryBlue)),
            const SizedBox(width: 10),
            Expanded(
                child: _summaryMetric(
                    'Completed', analytics.completed, const Color(0xFF059669))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _summaryMetric(
                    'Cancelled', analytics.cancelled, const Color(0xFFDC2626))),
            const SizedBox(width: 10),
            Expanded(
                child: _summaryMetric(
                    'Missed', analytics.missed, const Color(0xFFD97706))),
          ],
        ),
      ],
    );
  }

  Widget _summaryMetric(String label, int value, Color color) {
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$value',
              style: TextStyle(
                  color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQueuePerformance(List<AdminAnalyticsQueueService> services) {
    if (services.isEmpty) {
      return _buildMessage(
          'No service queue data for this period.', Icons.queue_rounded);
    }
    return Column(
      children: services.map((service) {
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD)),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.darkText)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _queueValue(
                      'Avg wait',
                      service.waitSamples == 0
                          ? '—'
                          : formatWaitDuration(service.averageWaitMinutes)),
                  _queueValue('Peak waiting', '${service.peakWaiting}'),
                  _queueValue(
                      'Congestion days', '${service.congestionIncidents}',
                      warning: service.congestionIncidents > 0),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _queueValue(String label, String value, {bool warning = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: warning
                      ? const Color(0xFFDC2626)
                      : AppTheme.primaryBlue)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppTheme.mutedText)),
        ],
      ),
    );
  }

  Widget _buildAppointmentTrend(List<AdminAnalyticsBucket> buckets) {
    if (buckets.isEmpty) {
      return _buildMessage(
          'No appointment history for this period.', Icons.event_busy_rounded);
    }
    return Column(
      children: buckets.map((bucket) {
        return Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFE0F2FE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(bucket.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkText))),
                  Text('${bucket.bookings} bookings',
                      style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
              const SizedBox(height: 9),
              _outcomeBar(bucket),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _legend('Done ${bucket.completed}', const Color(0xFF059669)),
                  _legend(
                      'Cancelled ${bucket.cancelled}', const Color(0xFFDC2626)),
                  _legend('Missed ${bucket.missed}', const Color(0xFFD97706)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _outcomeBar(AdminAnalyticsBucket bucket) {
    final other =
        (bucket.bookings - bucket.completed - bucket.cancelled - bucket.missed)
            .clamp(0, bucket.bookings);
    if (bucket.bookings == 0) {
      return Container(
          height: 8,
          decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8)));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            if (bucket.completed > 0)
              Expanded(
                  flex: bucket.completed,
                  child: Container(color: const Color(0xFF059669))),
            if (bucket.cancelled > 0)
              Expanded(
                  flex: bucket.cancelled,
                  child: Container(color: const Color(0xFFDC2626))),
            if (bucket.missed > 0)
              Expanded(
                  flex: bucket.missed,
                  child: Container(color: const Color(0xFFD97706))),
            if (other > 0)
              Expanded(
                  flex: other,
                  child: Container(color: const Color(0xFF38BDF8))),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.mutedText)),
        ],
      );

  Widget _buildSectionHeader(String title, IconData icon) => Row(
        children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppTheme.primaryBlue, size: 18)),
          const SizedBox(width: 9),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkText)),
        ],
      );

  Widget _buildMessage(String message, IconData icon) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD))),
        child: Column(children: [
          Icon(icon, size: 34, color: AppTheme.mutedText),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mutedText))
        ]),
      );
}
