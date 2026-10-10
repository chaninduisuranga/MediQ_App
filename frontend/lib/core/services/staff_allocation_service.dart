import 'queue_service.dart';

class GeneralOpdDoctor {
  final dynamic id;
  final String code;
  final String name;
  final String slmcNumber;
  final String room;
  final bool isAvailable;
  final List<Map<String, dynamic>> allocatedPatients;

  GeneralOpdDoctor({
    required this.id,
    required this.code,
    required this.name,
    required this.slmcNumber,
    required this.room,
    required this.isAvailable,
    List<Map<String, dynamic>>? allocatedPatients,
  }) : allocatedPatients = allocatedPatients ?? [];

  int get allocatedCount => allocatedPatients.length;

  String get assignedTokensText {
    if (allocatedPatients.isEmpty) return 'None';
    final tokens = allocatedPatients
        .map((patient) => (patient['queue_number'] ?? '').toString())
        .where((token) => token.isNotEmpty)
        .toList();
    return tokens.isEmpty ? 'None' : tokens.join(', ');
  }
}

class StaffAllocationService {
  static List<GeneralOpdDoctor> _doctors = [];
  static List<Map<String, dynamic>> _waitingPatients = [];
  static List<Map<String, dynamic>> _unallocatedWaitingPatients = [];

  static List<GeneralOpdDoctor> get doctors => List.unmodifiable(_doctors);

  static int get availableDoctorsCount =>
      _doctors.where((doctor) => doctor.isAvailable).length;

  static int get totalAllocatedCount =>
      _doctors.fold<int>(0, (sum, doctor) => sum + doctor.allocatedCount);

  static int get waitingCount => _waitingPatients.length;

  static int get unallocatedWaitingCount =>
      _unallocatedWaitingPatients.length;

  static Future<void> refreshData({String? roomKey}) async {
    final selectedRoom = roomKey ?? QueueService.selectedStaffRoomKey;
    final results = await Future.wait([
      QueueService.getStaffDoctors(roomKey: selectedRoom),
      QueueService.getStaffQueue(roomKey: selectedRoom),
    ]);
    final doctorData = results[0];
    final queue = results[1];
    final doctorsById = <String, GeneralOpdDoctor>{};

    _doctors = doctorData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final id = data['id'] ?? data['doctor_id'];
      if (id == null) {
        throw const FormatException('Staff doctor response is missing its ID.');
      }
      final doctor = GeneralOpdDoctor(
        id: id,
        code: (data['code'] ?? data['doctor_code'] ?? 'Doctor ${index + 1}')
            .toString(),
        name: (data['name'] ?? data['doctor_name'] ?? data['full_name'] ?? '')
            .toString(),
        slmcNumber:
            (data['slmc_number'] ?? data['slmc_no'] ?? '').toString(),
        room: (data['room'] ?? data['assigned_room'] ?? '').toString(),
        isAvailable: _availabilityFrom(data),
        allocatedPatients: _patientsFromDoctor(data),
      );
      doctorsById[id.toString()] = doctor;
      return doctor;
    }).toList();

    final allocatedPatientIds = <String>{};
    for (final doctor in _doctors) {
      for (final patient in doctor.allocatedPatients) {
        final id = patient['id'];
        if (id != null) allocatedPatientIds.add(id.toString());
      }
    }

    _waitingPatients = queue.where(_isWaiting).toList();
    for (final patient in _waitingPatients) {
      final assignedDoctor =
          patient['doctor'] ?? patient['allocated_doctor'];
      final assignedDoctorId = patient['doctor_id'] ??
          patient['allocated_doctor_id'] ??
          patient['assigned_doctor_id'] ??
          (assignedDoctor is Map
              ? assignedDoctor['id'] ?? assignedDoctor['doctor_id']
              : null);
      if (assignedDoctorId == null) continue;
      final doctor = doctorsById[assignedDoctorId.toString()];
      final patientId = patient['id'];
      if (doctor != null &&
          patientId != null &&
          allocatedPatientIds.add(patientId.toString())) {
        doctor.allocatedPatients.add(patient);
      }
    }
    _unallocatedWaitingPatients = _waitingPatients.where((patient) {
      final patientId = patient['id'];
      final assignedDoctorId = patient['doctor_id'] ??
          patient['allocated_doctor_id'] ??
          patient['assigned_doctor_id'] ??
          ((patient['doctor'] ?? patient['allocated_doctor']) is Map
              ? (patient['doctor'] ?? patient['allocated_doctor'])['id'] ??
                  (patient['doctor'] ?? patient['allocated_doctor'])
                      ['doctor_id']
              : null);
      return assignedDoctorId == null &&
          (patientId == null ||
              !allocatedPatientIds.contains(patientId.toString()));
    }).toList();
  }

  static bool _availabilityFrom(Map<String, dynamic> data) {
    final value = data['is_available'] ?? data['available'];
    if (value is bool) return value;
    if (value != null) {
      return value.toString().toUpperCase() == 'AVAILABLE' ||
          value.toString().toLowerCase() == 'true';
    }
    return true;
  }

  static List<Map<String, dynamic>> _patientsFromDoctor(
    Map<String, dynamic> data,
  ) {
    final patients =
        data['allocated_patients'] ??
        data['allocated_queue'] ??
        data['patients'] ??
        data['queue'];
    if (patients is! List) return [];
    return patients
        .whereType<Map>()
        .map((patient) => Map<String, dynamic>.from(patient))
        .toList();
  }

  static bool _isWaiting(Map<String, dynamic> patient) {
    final status = patient['status'];
    return status == 'CHECKED_IN' ||
        status == 'PENDING' ||
        status == 'CONFIRMED';
  }

  static Future<List<Map<String, dynamic>>> getTotalWaitingPatients() async {
    await refreshData();
    return List.unmodifiable(_waitingPatients);
  }

  static Future<List<Map<String, dynamic>>>
      getUnallocatedWaitingPatients() async {
    await refreshData();
    return List.unmodifiable(_unallocatedWaitingPatients);
  }

  static Future<Map<String, dynamic>> allocateNextBatch(
      {String? roomKey}) async {
    final selectedRoom = roomKey ?? QueueService.selectedStaffRoomKey;
    await refreshData(roomKey: selectedRoom);
    final availableDoctors =
        _doctors.where((doctor) => doctor.isAvailable).toList();
    if (availableDoctors.isEmpty) {
      return {
        'success': false,
        'message': 'No doctors are currently available for allocation.',
        'allocatedCount': 0,
      };
    }
    if (_unallocatedWaitingPatients.isEmpty) {
      return {
        'success': false,
        'message': 'No unallocated waiting patients found.',
        'allocatedCount': 0,
      };
    }

    int allocatedCount = 0;
    final failures = <String>[];
    final patientsByDoctor = <GeneralOpdDoctor, int>{};
    var doctorIndex = 0;
    for (final patient in _unallocatedWaitingPatients) {
      GeneralOpdDoctor? doctor;
      for (var attempt = 0; attempt < availableDoctors.length; attempt++) {
        final candidate =
            availableDoctors[(doctorIndex + attempt) % availableDoctors.length];
        if ((patientsByDoctor[candidate] ?? 0) < 5) {
          doctor = candidate;
          doctorIndex =
              (availableDoctors.indexOf(candidate) + 1) % availableDoctors.length;
          break;
        }
      }
      if (doctor == null) break;

      final patientId = int.tryParse(patient['id']?.toString() ?? '');
      if (patientId == null) {
        failures.add('A waiting patient has an invalid ID.');
        continue;
      }
      try {
        await QueueService.allocateStaffPatient(
          patientId,
          doctor.id,
          roomKey: selectedRoom,
        );
        doctor.allocatedPatients.add(patient);
        patientsByDoctor[doctor] = (patientsByDoctor[doctor] ?? 0) + 1;
        allocatedCount++;
      } catch (error) {
        failures.add(error.toString());
      }
    }

    final message = failures.isEmpty
        ? 'Successfully allocated $allocatedCount patient(s).'
        : 'Allocated $allocatedCount patient(s); ${failures.length} allocation(s) failed: ${failures.first}';
    return {
      'success': failures.isEmpty && allocatedCount > 0,
      'message': message,
      'allocatedCount': allocatedCount,
      'failedCount': failures.length,
    };
  }
}
