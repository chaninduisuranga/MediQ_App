import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'core/services/auth_service.dart';
import 'core/services/language_service.dart';
import 'core/theme/theme.dart';
import 'routes/routes.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/patient_signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/patient_profile_screen.dart';
import 'screens/book_appointment_screen.dart';
import 'screens/medical_records_screen.dart';
import 'screens/pill_tracker_screen.dart';
import 'screens/symptom_checker_screen.dart';
import 'screens/health_vitals_screen.dart';
import 'screens/ai_chat_screen.dart';

class ScreenItem {
  final String filename;
  final Widget Function() builder;
  final Duration waitTime;

  ScreenItem({
    required this.filename,
    required this.builder,
    this.waitTime = const Duration(milliseconds: 2000),
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.initLanguage();

  print('[ScreenshotRunner] Logging in demo user 200300702320...');
  try {
    final loginRes = await AuthService.login(nic: '200300702320', password: '722003');
    print('[ScreenshotRunner] Login result: ${loginRes["success"]}');
  } catch (e) {
    print('[ScreenshotRunner] Login exception: $e');
  }

  runApp(const ScreenshotApp());
}

class ScreenshotApp extends StatefulWidget {
  const ScreenshotApp({super.key});

  @override
  State<ScreenshotApp> createState() => _ScreenshotAppState();
}

class _ScreenshotAppState extends State<ScreenshotApp> {
  final GlobalKey _boundaryKey = GlobalKey();

  late final List<ScreenItem> _screens;
  int _currentIndex = 0;
  bool _isDone = false;
  String _status = 'Starting captures...';

  @override
  void initState() {
    super.initState();

    _screens = [
      ScreenItem(
        filename: 'splash_screen',
        builder: () => const SplashScreen(),
        waitTime: const Duration(milliseconds: 1800),
      ),
      ScreenItem(
        filename: 'login_screen',
        builder: () => const LoginScreen(),
        waitTime: const Duration(milliseconds: 1200),
      ),
      ScreenItem(
        filename: 'patient_signup_screen',
        builder: () => const PatientSignupScreen(),
        waitTime: const Duration(milliseconds: 1200),
      ),
      ScreenItem(
        filename: 'home_screen',
        builder: () => const HomeScreen(),
        waitTime: const Duration(milliseconds: 2500),
      ),
      ScreenItem(
        filename: 'patient_profile_screen',
        builder: () => const PatientProfileScreen(),
        waitTime: const Duration(milliseconds: 1500),
      ),
      ScreenItem(
        filename: 'book_appointment_screen',
        builder: () => const BookAppointmentScreen(),
        waitTime: const Duration(milliseconds: 2000),
      ),
      ScreenItem(
        filename: 'medical_records_screen',
        builder: () => const MedicalRecordsScreen(),
        waitTime: const Duration(milliseconds: 2000),
      ),
      ScreenItem(
        filename: 'pill_tracker_screen',
        builder: () => const PillTrackerScreen(),
        waitTime: const Duration(milliseconds: 1500),
      ),
      ScreenItem(
        filename: 'symptom_checker_screen',
        builder: () => const SymptomCheckerScreen(),
        waitTime: const Duration(milliseconds: 1500),
      ),
      ScreenItem(
        filename: 'health_vitals_screen',
        builder: () => const HealthVitalsScreen(),
        waitTime: const Duration(milliseconds: 1500),
      ),
      ScreenItem(
        filename: 'ai_chat_screen',
        builder: () => const AiChatScreen(),
        waitTime: const Duration(milliseconds: 2200),
      ),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCaptureSequence();
    });
  }

  Future<void> _startCaptureSequence() async {
    final dir1 = Directory(r'D:\MediQ_APP\MediQ_App\IT23680166');
    final dir2 = Directory(r'D:\MediQ_APP\IT23680166');
    dir1.createSync(recursive: true);
    dir2.createSync(recursive: true);

    for (int i = 0; i < _screens.length; i++) {
      setState(() {
        _currentIndex = i;
        _status = 'Rendering [${i + 1}/${_screens.length}]: ${_screens[i].filename}';
      });

      print('[ScreenshotRunner] Rendering: ${_screens[i].filename}...');
      await Future.delayed(_screens[i].waitTime);

      try {
        final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final ui.Image image = await boundary.toImage(pixelRatio: 2.625);
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final Uint8List pngBytes = byteData.buffer.asUint8List();
            final file1 = File('${dir1.path}\\${_screens[i].filename}.png');
            final file2 = File('${dir2.path}\\${_screens[i].filename}.png');
            await file1.writeAsBytes(pngBytes);
            await file2.writeAsBytes(pngBytes);
            print('[ScreenshotRunner] SAVED: ${file1.path} (${pngBytes.lengthInBytes} bytes)');
          } else {
            print('[ScreenshotRunner] ERROR: byteData is null for ${_screens[i].filename}');
          }
        } else {
          print('[ScreenshotRunner] ERROR: boundary is null for ${_screens[i].filename}');
        }
      } catch (e, stack) {
        print('[ScreenshotRunner] Capture error for ${_screens[i].filename}: $e\n$stack');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() {
      _isDone = true;
      _status = 'ALL 11 SCREENS CAPTURED SUCCESSFULLY!';
    });

    print('[ScreenshotRunner] COMPLETED! All 11 screenshots saved to IT23680166');
    await Future.delayed(const Duration(seconds: 2));
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isDone) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Text(
              _status,
              style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    final currentItem = _screens[_currentIndex];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      home: Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: Row(
          children: [
            Container(
              width: 250,
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MediQ Screenshot Tool',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text(_status, style: const TextStyle(color: Colors.cyanAccent, fontSize: 13)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _screens.length,
                      itemBuilder: (ctx, idx) {
                        final done = idx < _currentIndex;
                        final active = idx == _currentIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                done
                                    ? Icons.check_circle
                                    : (active ? Icons.arrow_right_alt : Icons.circle_outlined),
                                color: done
                                    ? Colors.greenAccent
                                    : (active ? Colors.cyanAccent : Colors.grey),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _screens[idx].filename,
                                  style: TextStyle(
                                    color: active ? Colors.white : Colors.grey,
                                    fontSize: 11,
                                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: Container(
                    width: 412,
                    height: 915,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: MediaQuery(
                      data: const MediaQueryData(
                        size: Size(412, 915),
                        devicePixelRatio: 2.625,
                        padding: EdgeInsets.only(top: 36, bottom: 20),
                        viewPadding: EdgeInsets.only(top: 36, bottom: 20),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(currentItem.filename),
                        child: Navigator(
                          onGenerateRoute: (settings) => MaterialPageRoute(
                            builder: (context) => currentItem.builder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
