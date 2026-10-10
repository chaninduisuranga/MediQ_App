class AdminAnalytics {
  const AdminAnalytics({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.bookings,
    required this.completed,
    required this.cancelled,
    required this.missed,
    required this.queueServices,
    required this.trend,
  });

  final String period;
  final String startDate;
  final String endDate;
  final int bookings;
  final int completed;
  final int cancelled;
  final int missed;
  final List<AdminAnalyticsQueueService> queueServices;
  final List<AdminAnalyticsBucket> trend;

  factory AdminAnalytics.fromJson(Map<String, dynamic> json) {
    final totals = json['appointments'] as Map<String, dynamic>? ?? {};
    return AdminAnalytics(
      period: json['period'] as String? ?? '30d',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      bookings: _intValue(totals['bookings']),
      completed: _intValue(totals['completed']),
      cancelled: _intValue(totals['cancelled']),
      missed: _intValue(totals['missed']),
      queueServices: (json['queue_services'] as List<dynamic>? ?? [])
          .map((item) =>
              AdminAnalyticsQueueService.fromJson(item as Map<String, dynamic>))
          .toList(),
      trend: (json['trend'] as List<dynamic>? ?? [])
          .map((item) =>
              AdminAnalyticsBucket.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdminAnalyticsQueueService {
  const AdminAnalyticsQueueService({
    required this.key,
    required this.name,
    required this.averageWaitMinutes,
    required this.waitSamples,
    required this.peakWaiting,
    required this.congestionIncidents,
  });

  final String key;
  final String name;
  final int averageWaitMinutes;
  final int waitSamples;
  final int peakWaiting;
  final int congestionIncidents;

  factory AdminAnalyticsQueueService.fromJson(Map<String, dynamic> json) =>
      AdminAnalyticsQueueService(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        averageWaitMinutes: _intValue(json['average_wait_minutes']),
        waitSamples: _intValue(json['wait_samples']),
        peakWaiting: _intValue(json['peak_waiting']),
        congestionIncidents: _intValue(json['congestion_incidents']),
      );
}

class AdminAnalyticsBucket {
  const AdminAnalyticsBucket({
    required this.label,
    required this.startDate,
    required this.bookings,
    required this.completed,
    required this.cancelled,
    required this.missed,
  });

  final String label;
  final String startDate;
  final int bookings;
  final int completed;
  final int cancelled;
  final int missed;

  factory AdminAnalyticsBucket.fromJson(Map<String, dynamic> json) =>
      AdminAnalyticsBucket(
        label: json['label'] as String? ?? '',
        startDate: json['start_date'] as String? ?? '',
        bookings: _intValue(json['bookings']),
        completed: _intValue(json['completed']),
        cancelled: _intValue(json['cancelled']),
        missed: _intValue(json['missed']),
      );
}

int _intValue(dynamic value) => (value as num?)?.toInt() ?? 0;
