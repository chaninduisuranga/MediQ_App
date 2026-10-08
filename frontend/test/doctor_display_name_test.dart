import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/doctor_display_name.dart';

void main() {
  test('adds one title when the stored name has no title', () {
    expect(formatDoctorDisplayName('Suneth Perera', fallback: 'Doctor'),
        'Dr. Suneth Perera');
  });

  test('does not duplicate repeated doctor titles', () {
    expect(formatDoctorDisplayName('Dr. Dr. Suneth Perera', fallback: 'Doctor'),
        'Dr. Suneth Perera');
  });

  test('uses the fallback when no name is available', () {
    expect(formatDoctorDisplayName(null, fallback: 'Doctor'), 'Dr. Doctor');
  });
}
