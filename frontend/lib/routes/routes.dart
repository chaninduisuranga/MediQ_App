import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/patient_signup_screen.dart';
import '../screens/patient_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/book_appointment_screen.dart';
import '../screens/medical_records_screen.dart';

import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_user_management_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profile = '/profile';
  static const String home = '/home';
  static const String bookAppointment = '/book-appointment';
  static const String medicalRecords = '/medical-records';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminUserManagement = '/admin/users';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        signup: (context) => const PatientSignupScreen(),
        profile: (context) => const PatientProfileScreen(),
        home: (context) => const HomeScreen(),
        bookAppointment: (context) => const BookAppointmentScreen(),
        medicalRecords: (context) => const MedicalRecordsScreen(),
        adminDashboard: (context) => const AdminDashboardScreen(),
        adminUserManagement: (context) => const AdminUserManagementScreen(),
      };
}
