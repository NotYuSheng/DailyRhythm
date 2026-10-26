import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'shared/services/backup/google_drive_service.dart';
import 'shared/services/backup/backup_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite for desktop platforms
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Hide system UI (navigation buttons) on mobile
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS)) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [], // Empty overlays = hide all system UI
    );
  }

  // Initialize Google Drive service
  await GoogleDriveService.instance.initialize();

  // Check if auto-backup is due and perform if needed
  BackupService.instance.performAutoBackupIfDue();

  runApp(
    const ProviderScope(
      child: DailyRhythmApp(),
    ),
  );
}

class DailyRhythmApp extends ConsumerWidget {
  const DailyRhythmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'DailyRhythm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRoutes.home,
      builder: (context, child) {
        // table_calendar and fl_chart still import the SDK's
        // material.dart; the bridge passes our theme to them. Remove once
        // they depend on package:material_ui.
        // ignore: deprecated_member_use
        final bridged = MaterialUiCompatibilityBridge(child: child!);
        if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
          return MobilePreviewWrapper(child: bridged);
        }
        return bridged;
      },
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
                color: Colors.black.withValues(alpha: 0.2),
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
