# Platform Support for Google Drive Backup

## Supported Platforms

### ✅ Fully Supported

#### Android
- **Status:** Full support
- **Requirements:**
  - Google Play Services installed
  - OAuth client ID configured with SHA-1 fingerprint
- **Setup:** See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md#for-android)
- **Notes:** Works seamlessly on all Android devices with Play Services

#### iOS
- **Status:** Full support
- **Requirements:**
  - OAuth client ID configured
  - URL scheme added to Info.plist
- **Setup:** See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md#for-ios)
- **Notes:** Works on all iOS devices (iPhone, iPad)

#### Web
- **Status:** Full support
- **Requirements:**
  - Web OAuth client ID configured
  - Client ID in index.html
- **Setup:** See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md#for-web)
- **Notes:** Works in all modern browsers

### ⚠️ Not Supported (Currently)

#### Linux Desktop
- **Status:** Not supported
- **Reason:** Google Sign-In plugin has no Linux implementation
- **Workaround:** Use web version or run on Android/iOS
- **Future:** May add alternative authentication method

#### Windows Desktop
- **Status:** Limited/Experimental support
- **Reason:** Google Sign-In plugin has limited Windows support
- **Workaround:** Use web version or run on Android/iOS
- **Notes:** May work with additional configuration

#### macOS Desktop
- **Status:** Experimental support
- **Reason:** Google Sign-In plugin has experimental macOS support
- **Workaround:** Use iOS version or web version
- **Notes:** May work but not officially supported

## Platform Detection

The app automatically detects the platform and:

1. **On Supported Platforms (Android, iOS, Web):**
   - Google Sign-In works normally
   - All backup features available
   - No warnings shown

2. **On Unsupported Platforms (Linux, Windows, macOS desktop):**
   - Shows orange warning banner in Backup Settings screen
   - Sign-in button disabled or shows error message
   - Gracefully handles plugin errors
   - No app crashes

## Error Handling

### MissingPluginException

This error occurs on unsupported platforms. The app handles it by:

```dart
// In GoogleDriveService
bool _isPlatformSupported() {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS;
}
```

- Checks platform before initializing
- Shows user-friendly error message
- Prevents app crashes
- Maintains app stability

### User Experience on Unsupported Platforms

When running on Linux/Windows/macOS:

1. **Backup Settings Screen:**
   - Orange warning banner appears
   - Message: "Platform Not Supported"
   - Explains which platforms are supported
   - All other app features work normally

2. **If User Tries to Sign In:**
   - Shows error message
   - Suggests running on supported platform
   - No crash or unexpected behavior

## Testing on Different Platforms

### Android Testing

```bash
# Connect Android device or start emulator
flutter devices
flutter run -d <android-device-id>
```

### iOS Testing

```bash
# Connect iOS device or start simulator
flutter devices
flutter run -d <ios-device-id>
```

### Web Testing

```bash
# Run on Chrome
flutter run -d chrome

# Run on Edge
flutter run -d edge
```

### Linux Testing (for development)

```bash
# The app will run but backup features will show warning
flutter run -d linux
```

## Development Workflow

### Recommended Setup

1. **Primary Development:** Use Android emulator or iOS simulator
2. **Testing:** Test on actual devices before release
3. **UI Development:** Can use Linux/desktop for non-backup features
4. **Backup Testing:** Must use Android, iOS, or Web

### Flutter Desktop Preview

The app includes a mobile preview wrapper for desktop:

```dart
// In main.dart
kIsWeb || defaultTargetPlatform == TargetPlatform.linux
    ? const MobilePreviewWrapper(child: HomeScreen())
    : const HomeScreen()
```

This allows you to develop on Linux while seeing mobile-sized UI.

## Future Enhancements

### Potential Desktop Support Options

1. **Alternative Authentication:**
   - OAuth via browser redirect
   - Manual token entry
   - QR code authentication

2. **Alternative Backup Methods:**
   - Local file export/import
   - Network share backup
   - Custom cloud provider

3. **Third-Party Solutions:**
   - Use different Google auth library
   - Implement custom OAuth flow
   - Platform-specific implementations

## FAQ

### Q: Why doesn't it work on Linux?
**A:** Google Sign-In plugin doesn't have a Linux implementation. This is a limitation of the plugin, not our code.

### Q: Can I test the backup feature on my Linux dev machine?
**A:** No, you need to use Android emulator, iOS simulator, or web browser for testing backup features.

### Q: Will this be fixed in the future?
**A:** It depends on the google_sign_in package maintainers. We'll update when desktop support is added.

### Q: Can I use the rest of the app on Linux?
**A:** Yes! All other features (journal, tags, export/import, etc.) work perfectly on all platforms.

### Q: What should I tell users?
**A:** The app is designed for mobile (Android/iOS). Desktop versions work but with limited cloud backup support.

## Platform-Specific Code

### Checking Platform Support

```dart
import 'package:flutter/foundation.dart';

bool isPlatformSupported() {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS;
}
```

### Conditional UI

```dart
if (!platformSupported)
  Card(
    child: Text('This feature requires Android, iOS, or Web'),
  ),
```

### Error Handling

```dart
try {
  await _driveService.signIn();
} on UnsupportedError catch (e) {
  // Show platform not supported message
} catch (e) {
  // Handle other errors
}
```

## Summary

| Platform | Support | Sign-In | Backup | Restore | Notes |
|----------|---------|---------|--------|---------|-------|
| Android  | ✅ Full | ✅ Yes  | ✅ Yes | ✅ Yes  | Recommended |
| iOS      | ✅ Full | ✅ Yes  | ✅ Yes | ✅ Yes  | Recommended |
| Web      | ✅ Full | ✅ Yes  | ✅ Yes | ✅ Yes  | Works in browser |
| Linux    | ⚠️ Limited | ❌ No | ❌ No | ❌ No | Dev only |
| Windows  | ⚠️ Experimental | ⚠️ Maybe | ⚠️ Maybe | ⚠️ Maybe | Not tested |
| macOS    | ⚠️ Experimental | ⚠️ Maybe | ⚠️ Maybe | ⚠️ Maybe | Not tested |

---

**Recommendation:** Deploy and distribute the app primarily for Android and iOS platforms.
