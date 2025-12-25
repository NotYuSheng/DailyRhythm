/// Defines all route names used in the application
/// Use these constants for type-safe navigation
class AppRoutes {
  // Prevent instantiation
  AppRoutes._();

  // Main navigation
  static const String home = '/';
  static const String journal = '/journal';
  static const String calendar = '/calendar';
  static const String metrics = '/metrics';
  static const String settings = '/settings';

  // Sleep
  static const String addSleep = '/sleep/add';

  // Meals
  static const String addMeal = '/meals/add';

  // Exercise
  static const String addExercise = '/exercise/add';

  // Settings
  static const String backupSettings = '/settings/backup';

  // Tags
  static const String tags = '/tags';
}
