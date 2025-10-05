# LifeRhythm

A daily stats tracking Flutter app with monochrome rhythm aesthetic.

> [!NOTE]  
> Thank you for visiting! This project is currently a work in progress. Features, documentation, and deployment configurations are actively being developed and may change frequently.

## Development Setup

### Prerequisites
- Flutter SDK installed and configured
- A device or emulator for testing
- **For Linux development**: SQLite3 library
  ```bash
  sudo apt-get install libsqlite3-dev
  ```

### Running in Development Mode

1. **First-time setup:**
   ```bash
   # Navigate to the project directory
   cd LifeRhythm

   # Get dependencies
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   # For Linux
   flutter run -d linux

   # For other platforms
   flutter run -d chrome    # Web
   flutter run -d android   # Android
   flutter run -d ios       # iOS (macOS only)
   flutter run -d macos     # macOS
   flutter run -d windows   # Windows
   ```

3. **Hot Reload (Dev Mode) 🔥**

   Once the app is running, you can make code changes and see them instantly:

   - **Save your file changes** in your IDE
   - Go to the terminal where `flutter run` is active
   - Press **`r`** to hot reload (updates UI, preserves state)
   - Press **`R`** to hot restart (full restart, resets state)

   **Other useful commands:**
   - `h` - Show all available commands
   - `c` - Clear the screen
   - `q` - Quit the app
   - `d` - Detach (app keeps running)

4. **Clean build (if needed):**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d linux
   ```

### Common Issues

- **CMake cache errors**: Run `flutter clean` first
- **Hot reload not working**: Try hot restart with `R` or restart the app
- **Dependency issues**: Run `flutter pub get`
- **SQLite errors on Linux**: Make sure `libsqlite3-dev` is installed (see Prerequisites)

---

## Deployment Notes

### For Production Release

**⚠️ TODO Before Distribution:**

The current setup uses system SQLite libraries for development. Before distributing the app to users, you need to bundle SQLite so the app is self-contained:

1. Add `sqlite3_flutter_libs` to `pubspec.yaml`:
   ```yaml
   dependencies:
     sqlite3_flutter_libs: ^0.5.0
   ```

2. This will bundle SQLite with your app so users don't need to install system libraries

3. Platforms affected:
   - ✅ **Android/iOS**: Works automatically, no changes needed
   - ⚠️ **Linux/Windows/macOS**: Need bundled SQLite for distribution

**Why we're not doing this now:**
- Development is faster with system libraries
- Bundle SQLite only when preparing for release
- Keeps development environment simple

## Project Overview

LifeRhythm tracks your daily stats including:
- Sleep patterns
- Meals and costs
- Mood tracking with emoji buttons

Built with a pure monochrome design aesthetic for minimal distraction.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
