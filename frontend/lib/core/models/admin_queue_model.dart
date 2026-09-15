class AdminQueue {
  const AdminQueue({
    required this.key,
    required this.name,
    required this.waiting,
    required this.serving,
    required this.completed,
    required this.averageWaitMinutes,
    required this.congestionStatus,
    required this.recommendedAction,
  });

  final String key;
  final String name;
  final int waiting;
  final int serving;
  final int completed;
  final int averageWaitMinutes;
  final String congestionStatus;
  final String recommendedAction;

  factory AdminQueue.fromJson(Map<String, dynamic> json) => AdminQueue(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        waiting: (json['waiting'] as num?)?.toInt() ?? 0,
        serving: (json['serving'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        averageWaitMinutes:
            (json['average_wait_minutes'] as num?)?.toInt() ?? 0,
        congestionStatus: json['congestion_status'] as String? ?? 'NORMAL',
        recommendedAction: json['recommended_action'] as String? ?? '',
      );
}

class AdminQueueAlert {
  const AdminQueueAlert({
    required this.queueName,
    required this.waiting,
    required this.averageWaitMinutes,
    required this.status,
    required this.recommendedAction,
  });

  final String queueName;
  final int waiting;
  final int averageWaitMinutes;
  final String status;
  final String recommendedAction;

  factory AdminQueueAlert.fromJson(Map<String, dynamic> json) =>
      AdminQueueAlert(
        queueName: json['queue_name'] as String? ?? '',
        waiting: (json['waiting'] as num?)?.toInt() ?? 0,
        averageWaitMinutes:
            (json['average_wait_minutes'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'WARNING',
        recommendedAction: json['recommended_action'] as String? ?? '',
      );
}
