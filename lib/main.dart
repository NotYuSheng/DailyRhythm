import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  // Initialize sqflite for desktop platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    const ProviderScope(
      child: LifeRhythmApp(),
    ),
  );
}

class LifeRhythmApp extends StatelessWidget {
  const LifeRhythmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeRhythm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // TODO: Add theme mode toggle
      home: kIsWeb || defaultTargetPlatform == TargetPlatform.linux
          ? const MobilePreviewWrapper(child: HomeScreen())
          : const HomeScreen(),
    );
  }
}

/// Wrapper to show mobile preview on desktop/web
class MobilePreviewWrapper extends StatelessWidget {
  final Widget child;

  const MobilePreviewWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: Center(
        child: Container(
          width: 412, // Samsung Galaxy S24 FE width
          height: 915, // Samsung Galaxy S24 FE height
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
