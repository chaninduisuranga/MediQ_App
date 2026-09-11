import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/patient_signup_screen.dart';
import '../screens/patient_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/book_appointment_screen.dart';
import '../screens/medical_records_screen.dart';
import '../screens/staff_dashboard_screen.dart';
import '../screens/opd_queue_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/check_in_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profile = '/profile';
  static const String home = '/home';
  static const String bookAppointment = '/book-appointment';
  static const String medicalRecords = '/medical-records';
  static const String staffDashboard = '/staff-dashboard';
  static const String opdQueue = '/opd-queue';
  static const String qrScanner = '/qr-scanner';
  static const String checkIn = '/check-in';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        signup: (context) => const PatientSignupScreen(),
        profile: (context) => const PatientProfileScreen(),
        home: (context) => const HomeScreen(),
        bookAppointment: (context) => const BookAppointmentScreen(),
        medicalRecords: (context) => const MedicalRecordsScreen(),
        staffDashboard: (context) => const StaffDashboardScreen(),
        opdQueue: (context) => const OpdQueueScreen(),
        qrScanner: (context) => const QrScannerScreen(),
        checkIn: (context) => const CheckInScreen(),
      };
}
