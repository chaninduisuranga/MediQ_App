import 'dart:async';
import 'queue_service.dart';

class GeneralOpdDoctor {
  final String id;
  final String code; // e.g. "Doctor 01"
  final String name;
  final String slmcNumber;
  final String room;
  bool isAvailable;
  List<Map<String, dynamic>> allocatedPatients;

  GeneralOpdDoctor({
    required this.id,
    required this.code,
    required this.name,
    required this.slmcNumber,
    required this.room,
    this.isAvailable = true,
    List<Map<String, dynamic>>? allocatedPatients,
  }) : allocatedPatients = allocatedPatients ?? [];

  int get allocatedCount => allocatedPatients.length;

  String get assignedTokensText {
    if (allocatedPatients.isEmpty) return 'None';
    final tokens = allocatedPatients
        .map((p) => (p['queue_number'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return 'None';
    return tokens.join(', ');
  }
}

class StaffAllocationService {
  static final List<GeneralOpdDoctor> _doctors = [
    GeneralOpdDoctor(
      id: 'DOC-G01',
      code: 'Doctor 01',
      name: 'Dr. Suneth Perera',
      slmcNumber: 'SLMC-29841',
      room: 'General OPD — Room 01',
      isAvailable: true,
    ),
    GeneralOpdDoctor(
      id: 'DOC-G02',
      code: 'Doctor 02',
      name: 'Dr. Nimali Jayawardena',
      slmcNumber: 'SLMC-31204',
      room: 'General OPD — Room 02',
      isAvailable: true,
    ),
    GeneralOpdDoctor(
      id: 'DOC-G03',
      code: 'Doctor 03',
      name: 'Dr. Kasun Bandara',
      slmcNumber: 'SLMC-34512',
      room: 'General OPD — Room 03',
      isAvailable: true,
    ),
    GeneralOpdDoctor(
      id: 'DOC-G04',
      code: 'Doctor 04',
      name: 'Dr. Chamari Silva',
      slmcNumber: 'SLMC-38902',
      room: 'General OPD — Room 04',
      isAvailable: true,
    ),
  ];

  static final Set<dynamic> _allocatedPatientIds = {};
  static final StreamController<List<GeneralOpdDoctor>> _allocationController =
      StreamController<List<GeneralOpdDoctor>>.broadcast();

  static Stream<List<GeneralOpdDoctor>> get doctorsStream =>
      _allocationController.stream;

  static List<GeneralOpdDoctor> get doctors => List.unmodifiable(_doctors);

  static int get availableDoctorsCount =>
      _doctors.where((d) => d.isAvailable).length;

  static int get totalAllocatedCount {
    return _doctors.fold<int>(0, (sum, d) => sum + d.allocatedCount);
  }

  static void setDoctorAvailability(String doctorId, bool isAvailable) {
    final doc = _doctors.firstWhere(
      (d) => d.id == doctorId,
      orElse: () => _doctors.first,
    );
    doc.isAvailable = isAvailable;
    _allocationController.add(_doctors);
  }

  /// Get all waiting patients in GENERAL_OPD queue
  static Future<List<Map<String, dynamic>>> getTotalWaitingPatients() async {
    final queue = await QueueService.getQueueByRoom('GENERAL_OPD');
    return queue.where((patient) {
      final status = patient['status'];
      return status == 'CHECKED_IN' ||
          status == 'PENDING' ||
          status == 'CONFIRMED';
    }).toList();
  }

  /// Get waiting patients for GENERAL_OPD who have NOT been allocated to any doctor yet
  static Future<List<Map<String, dynamic>>> getUnallocatedWaitingPatients() async {
    final queue = await QueueService.getQueueByRoom('GENERAL_OPD');
    return queue.where((patient) {
      final id = patient['id'];
      final status = patient['status'];
      final isWaiting = status == 'CHECKED_IN' ||
          status == 'PENDING' ||
          status == 'CONFIRMED';
      return isWaiting && !_allocatedPatientIds.contains(id);
    }).toList();
  }

  /// Batch allocation:
  /// Allocates up to 5 patients per available doctor.
  /// If all 4 doctors available and >=20 waiting, allocates 5 to each (20 total).
  /// If fewer available, distributes waiting patients up to 5 per available doctor.
  /// Unavailable doctors receive 0 patients.
  static Future<Map<String, dynamic>> allocateNextBatch() async {
    final availableDocs = _doctors.where((d) => d.isAvailable).toList();
    if (availableDocs.isEmpty) {
      return {
        'success': false,
        'message': 'No doctors are currently marked as available/on-duty.',
        'allocatedCount': 0,
      };
    }

    final waiting = await getUnallocatedWaitingPatients();
    if (waiting.isEmpty) {
      return {
        'success': false,
        'message': 'No unallocated waiting patients found in General OPD queue.',
        'allocatedCount': 0,
      };
    }

    int allocatedTotal = 0;
    int waitingIndex = 0;
    const maxPerDoctor = 5;

    // Distribute up to 5 patients per available doctor
    for (final doc in availableDocs) {
      int countForThisDoc = 0;
      while (countForThisDoc < maxPerDoctor && waitingIndex < waiting.length) {
        final patient = Map<String, dynamic>.from(waiting[waitingIndex]);
        patient['allocated_doctor_id'] = doc.id;
        patient['allocated_doctor_name'] = doc.name;
        patient['allocated_doctor_code'] = doc.code;
        patient['allocation_time'] = DateTime.now().toIso8601String();

        doc.allocatedPatients.add(patient);
        _allocatedPatientIds.add(patient['id']);

        waitingIndex++;
        countForThisDoc++;
        allocatedTotal++;
      }
      if (waitingIndex >= waiting.length) break;
    }

    _allocationController.add(_doctors);

    return {
      'success': true,
      'message':
          'Successfully allocated $allocatedTotal patient(s) across ${availableDocs.length} available doctor(s).',
      'allocatedCount': allocatedTotal,
    };
  }

  static GeneralOpdDoctor? getDoctorById(String doctorId) {
    try {
      return _doctors.firstWhere((d) => d.id == doctorId);
    } catch (_) {
      return null;
    }
  }

  static void clearDoctorAllocation(String doctorId) {
    final doc = getDoctorById(doctorId);
    if (doc != null) {
      for (final p in doc.allocatedPatients) {
        _allocatedPatientIds.remove(p['id']);
      }
      doc.allocatedPatients.clear();
      _allocationController.add(_doctors);
    }
  }

  static void resetAllAllocations() {
    for (final doc in _doctors) {
      for (final p in doc.allocatedPatients) {
        _allocatedPatientIds.remove(p['id']);
      }
      doc.allocatedPatients.clear();
    }
    _allocatedPatientIds.clear();
    _allocationController.add(_doctors);
  }
}
