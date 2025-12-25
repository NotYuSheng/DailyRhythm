import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../../features/sleep/presentation/screens/add_sleep_screen.dart';
import '../../features/meals/presentation/screens/add_meal_screen.dart';
import '../../features/exercise/presentation/screens/add_exercise_screen.dart';
import '../../features/settings/presentation/screens/backup_settings_screen.dart';
import '../../features/tags/presentation/screens/tags_screen.dart';
import 'app_routes.dart';

/// Handles route generation for the entire app
/// Provides type-safe navigation with named routes
class AppRouter {
  // Prevent instantiation
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case AppRoutes.addSleep:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AddSleepScreen(
            entry: args?['entry'],
            date: args?['date'],
          ),
        );

      case AppRoutes.addMeal:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AddMealScreen(entry: args?['entry']),
        );

      case AppRoutes.addExercise:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AddExerciseScreen(entry: args?['entry']),
        );

      case AppRoutes.backupSettings:
        return MaterialPageRoute(
          builder: (_) => const BackupSettingsScreen(),
        );

      case AppRoutes.tags:
        return MaterialPageRoute(
          builder: (_) => const TagsScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
