import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/patient_signup_screen.dart';
import '../screens/patient_profile_screen.dart';
import '../screens/home_screen.dart';
import '../screens/book_appointment_screen.dart';
import '../screens/medical_records_screen.dart';
import '../screens/pill_tracker_screen.dart';
import '../screens/symptom_checker_screen.dart';
import '../screens/health_vitals_screen.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/staff_dashboard_screen.dart';
import '../screens/opd_queue_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/check_in_screen.dart';
import '../screens/staff_profile_screen.dart';
import '../screens/queue_history_screen.dart';

import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_user_management_screen.dart';
import '../screens/admin_appointment_management_screen.dart';
import '../screens/admin_clinical_staff_management_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profile = '/profile';
  static const String home = '/home';
  static const String bookAppointment = '/book-appointment';
  static const String medicalRecords = '/medical-records';
  static const String pillTracker = '/pill-tracker';
  static const String symptomChecker = '/symptom-checker';
  static const String healthVitals = '/health-vitals';
  static const String aiChat = '/ai-chat';
  static const String adminDashboard = '/admin-dashboard';
  static const String adminUserManagement = '/admin/users';
  static const String adminAppointmentManagement = '/admin/appointments';
  static const String adminClinicalStaffManagement = '/admin/clinical-staff';
  static const String staffDashboard = '/staff-dashboard';
  static const String opdQueue = '/opd-queue';
  static const String qrScanner = '/qr-scanner';
  static const String checkIn = '/check-in';
  static const String staffProfile = '/staff-profile';
  static const String queueHistory = '/queue-history';

  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        login: (context) => const LoginScreen(),
        signup: (context) => const PatientSignupScreen(),
        profile: (context) => const PatientProfileScreen(),
        home: (context) => const HomeScreen(),
        bookAppointment: (context) => const BookAppointmentScreen(),
        medicalRecords: (context) => const MedicalRecordsScreen(),
        pillTracker: (context) => const PillTrackerScreen(),
        symptomChecker: (context) => const SymptomCheckerScreen(),
        healthVitals: (context) => const HealthVitalsScreen(),
        aiChat: (context) => const AiChatScreen(),
        adminDashboard: (context) => const AdminDashboardScreen(),
        adminUserManagement: (context) => const AdminUserManagementScreen(),
        adminAppointmentManagement: (context) =>
            const AdminAppointmentManagementScreen(),
        adminClinicalStaffManagement: (context) =>
            const AdminClinicalStaffManagementScreen(),
        staffDashboard: (context) => const StaffDashboardScreen(),
        opdQueue: (context) => const OpdQueueScreen(),
        qrScanner: (context) => const QrScannerScreen(),
        checkIn: (context) => const CheckInScreen(),
        staffProfile: (context) => const StaffProfileScreen(),
        queueHistory: (context) => const QueueHistoryScreen(),
      };
}
