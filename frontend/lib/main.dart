import 'package:flutter/material.dart';
import 'core/services/language_service.dart';
import 'core/theme/theme.dart';
import 'routes/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LanguageService.initLanguage();
  runApp(const MediQApp());
}

class MediQApp extends StatelessWidget {
  const MediQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'MediQ',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
