# DailyRhythm

A daily stats tracking Flutter app with rhythm aesthetic.

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
   cd DailyRhythm

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

### Running on Android Device (Physical Phone)

1. **Enable Developer Options on your phone:**
   - Go to **Settings** → **About phone**
   - Tap **Build number** 7 times
   - You'll see "You are now a developer!"

2. **Enable USB Debugging:**
   - Go to **Settings** → **System** → **Developer options**
   - Enable **USB debugging**

3. **For Samsung devices - Disable Auto Blocker:**
   - Go to **Settings** → **Security and privacy** → **Auto Blocker**
   - Turn off **Auto Blocker** (it blocks USB debugging)

4. **Connect your phone:**
   ```bash
   # Connect phone via USB cable

   # Change USB mode on your phone:
   # When you plug in the USB cable, pull down the notification shade
   # Tap on "Charging this device via USB" or "USB for charging"
   # Select "File Transfer" or "MTP" mode (NOT just "Charging")

   # Check if device is detected
   adb devices

   # You should see your device listed
   # If it shows "unauthorized", accept the USB debugging prompt on your phone
   ```

5. **Run the app on your phone:**
   ```bash
   # List all connected devices
   flutter devices

   # Run on connected Android device
   flutter run -d android

   # Or specify device ID if multiple devices
   flutter run -d <device-id>
   ```

6. **Troubleshooting:**
   - **Device not showing up**: Check USB cable, try different USB port
   - **"Unauthorized" status**: Accept USB debugging prompt on phone
   - **Install failed (signature mismatch)**: Uninstall old version first
     ```bash
     adb uninstall com.dailyrhythm.dailyrhythm
     ```
   - **Auto Blocker issues (Samsung)**: Make sure Auto Blocker is disabled

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

DailyRhythm tracks your daily stats including:
- Sleep patterns
- Meals and costs
- Mood tracking with emoji buttons

Built with a minimal aesthetic design.

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
