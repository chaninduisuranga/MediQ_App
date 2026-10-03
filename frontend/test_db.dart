import 'package:postgres/postgres.dart';

void main() async {
  final conn = await Connection.open(
    Endpoint(
      host: 'aws-0-ap-south-1.pooler.supabase.com',
      database: 'postgres',
      username: 'postgres.dvanmlqqgvbltdvwamuk',
      password: '3141531415supabase',
      port: 5432,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );
  
  final res = await conn.execute('SELECT id, patient_id, appointment_time, appointment_date, notes FROM opd_appointments');
  print('opd_appointments:');
  for (final row in res) {
    print(row);
  }
  
  final users = await conn.execute('SELECT id, blood_group, allergies, medical_conditions, address FROM users');
  print('users:');
  for (final row in users) {
    print(row);
  }
  
  await conn.close();
}
