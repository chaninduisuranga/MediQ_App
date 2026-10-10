import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/services/doctor_service.dart';
import 'package:frontend/core/services/queue_service.dart';

void main() {
  group('DoctorService appointment queue status', () {
    test('recognizes current patients across API status fields', () {
      expect(
        DoctorService.isAppointmentInConsultation({
          'status': 'SERVING',
        }),
        isTrue,
      );
      expect(
        DoctorService.isAppointmentInConsultation({
          'consultation_status': 'in consultation',
        }),
        isTrue,
      );
      expect(
        DoctorService.isAppointmentInConsultation({
          'queue_status': 'IN_PROGRESS',
        }),
        isTrue,
      );
    });

    test('recognizes waiting patients and excludes current patients', () {
      expect(
        DoctorService.isAppointmentWaiting({
          'status': 'CONFIRMED',
        }),
        isTrue,
      );
      expect(
        DoctorService.isAppointmentWaiting({
          'queue_status': 'CHECKED_IN',
          'appointment_status': 'IN_CONSULTATION',
        }),
        isFalse,
      );
      expect(
        DoctorService.isAppointmentWaiting({
          'appointment_status': 'COMPLETED',
        }),
        isFalse,
      );
    });

    test('recognizes active queue entries across status fields', () {
      expect(
        QueueService.isQueueEntryActive({
          'status': 'in-consultation',
        }),
        isTrue,
      );
      expect(
        QueueService.isQueueEntryActive({
          'is_active': true,
        }),
        isTrue,
      );
      expect(
        QueueService.isQueueEntryActive({
          'queue_status': 'CHECKED_IN',
        }),
        isFalse,
      );
    });
  });
}
