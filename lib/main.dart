import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config/backend_config.dart';
import 'firebase_options.dart';
import 'home_page.dart';
import 'navigation_observer.dart';
import 'services/firebase_service.dart';

// ⚠️ ADJUST THIS PATH to wherever theme_controller.dart actually lives —
// it must sit in the same folder as student_settings_page.dart.
import 'student/pages/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (BackendConfig.useFirebase) {
    if (!DefaultFirebaseOptions.isConfigured) {
      throw StateError(
        'Firebase is enabled but lib/firebase_options.dart is not configured. '
        'Run: dart pub global activate flutterfire_cli && flutterfire configure',
      );
    }

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseService.restoreSessionIfNeeded();
  }

  // Load the saved Dark Mode preference before the first frame so the
  // app opens directly in the right theme instead of flashing light
  // mode first.
  await ThemeController.instance.load();

  runApp(const HostelApp());
}

class HostelApp extends StatelessWidget {
  const HostelApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds MaterialApp whenever ThemeController.instance changes —
    // i.e. whenever the Dark Mode switch in Settings is toggled.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'RIT Hostel',
          themeMode: ThemeController.instance.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: Colors.blue,
            textTheme: GoogleFonts.playfairDisplayTextTheme(
              ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
              ).textTheme,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.blue,
            textTheme: GoogleFonts.playfairDisplayTextTheme(
              ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
              ).textTheme,
            ),
          ),
          home: const HomePage(),
          navigatorObservers: [routeObserver],
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}