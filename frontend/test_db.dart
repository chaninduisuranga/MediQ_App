import 'dart:io';
import 'package:postgres/postgres.dart';

void main() async {
  const envKeys = [
    'SUPABASE_DB_HOST',
    'SUPABASE_DB_NAME',
    'SUPABASE_DB_USER',
    'SUPABASE_DB_PASSWORD',
  ];
  final missing = envKeys
      .where((key) => (Platform.environment[key] ?? '').isEmpty)
      .toList();
  if (missing.isNotEmpty) {
    stderr.writeln(
        'Set these environment variables to run this script: ${missing.join(', ')}');
    exitCode = 1;
    return;
  }
  final port = int.tryParse(Platform.environment['SUPABASE_DB_PORT'] ?? '5432');
  if (port == null) {
    stderr.writeln('SUPABASE_DB_PORT must be a valid port number.');
    exitCode = 1;
    return;
  }

  final conn = await Connection.open(
    Endpoint(
      host: Platform.environment['SUPABASE_DB_HOST']!,
      database: Platform.environment['SUPABASE_DB_NAME']!,
      username: Platform.environment['SUPABASE_DB_USER']!,
      password: Platform.environment['SUPABASE_DB_PASSWORD']!,
      port: port,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.require),
  );

  final res = await conn.execute(
      'SELECT id, patient_id, appointment_time, appointment_date, notes FROM opd_appointments');
  stdout.writeln('opd_appointments:');
  for (final row in res) {
    stdout.writeln(row);
  }

  final users = await conn.execute(
      'SELECT id, blood_group, allergies, medical_conditions, address FROM users');
  stdout.writeln('users:');
  for (final row in users) {
    stdout.writeln(row);
  }

  await conn.close();
}
