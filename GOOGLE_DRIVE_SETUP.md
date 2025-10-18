# Google Drive Backup Setup Guide

This guide will help you configure Google Drive backup functionality for LifeRhythm.

## Prerequisites

You need to create a Google Cloud Project and configure OAuth 2.0 credentials.

## Setup Steps

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Name it something like "LifeRhythm Backup"

### 2. Enable Google Drive API

1. In the Google Cloud Console, go to **APIs & Services > Library**
2. Search for "Google Drive API"
3. Click on it and press **Enable**

### 3. Configure OAuth Consent Screen

1. Go to **APIs & Services > OAuth consent screen**
2. Choose **External** user type (unless you have a Google Workspace)
3. Fill in the required information:
   - App name: `LifeRhythm`
   - User support email: Your email
   - Developer contact: Your email
4. Add scopes:
   - `../auth/drive.file` - View and manage Google Drive files created by this app
   - `../auth/drive.appdata` - View and manage app-specific data
5. Add test users (your email addresses for testing)
6. Save and continue

### 4. Create OAuth 2.0 Credentials

#### For Android:

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose **Android** as the application type
4. Get your SHA-1 certificate fingerprint:

   **For Debug (development):**
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Look for the SHA-1 under `Variant: debug` and `Config: debug`

   **Alternatively, use keytool:**
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

5. Enter the details:
   - Name: `LifeRhythm Android`
   - Package name: `com.example.life_rhythm` (check `android/app/build.gradle` for actual package)
   - SHA-1 certificate fingerprint: (paste the SHA-1 from step 4)
6. Click **Create**
7. **Note:** You don't need to download anything for Android

#### For iOS:

1. Click **Create Credentials > OAuth client ID**
2. Choose **iOS** as the application type
3. Enter details:
   - Name: `LifeRhythm iOS`
   - Bundle ID: Check `ios/Runner/Info.plist` for `CFBundleIdentifier`
     - Typically: `com.example.lifeRhythm` or similar
4. Click **Create**
5. Download the configuration file (you'll get a `.plist` file)
6. Copy the **iOS URL scheme** (looks like: `com.googleusercontent.apps.123456789-abcdef...`)

#### For Web:

1. Click **Create Credentials > OAuth client ID**
2. Choose **Web application**
3. Enter details:
   - Name: `LifeRhythm Web`
   - Authorized JavaScript origins:
     - `http://localhost` (for local testing)
     - Your production domain when deployed
   - Authorized redirect URIs:
     - `http://localhost` (for local testing)
4. Click **Create**
5. Copy the **Client ID** (you'll need this)

### 5. Configure Your Flutter App

#### Android Configuration:

No additional configuration needed! The package will automatically use your Google Cloud Project credentials.

#### iOS Configuration:

1. Open `ios/Runner/Info.plist`
2. Add the following before the last `</dict>`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Replace with your iOS URL scheme from Google Cloud Console -->
      <string>com.googleusercontent.apps.YOUR-CLIENT-ID</string>
    </array>
  </dict>
</array>
```

Replace `YOUR-CLIENT-ID` with the reversed client ID from your iOS OAuth credentials.

#### Web Configuration:

1. Create or edit `web/index.html`
2. Add the following in the `<head>` section:

```html
<meta name="google-signin-client_id" content="YOUR-WEB-CLIENT-ID.apps.googleusercontent.com">
```

Replace `YOUR-WEB-CLIENT-ID` with your Web OAuth client ID.

### 6. Test the Integration

1. Run your app:
   ```bash
   flutter run
   ```

2. Navigate to: **Settings > Backup & Sync**

3. Tap **Sign in with Google**

4. Follow the Google sign-in flow

5. Once signed in, you should see:
   - Your email address
   - Backup actions
   - Auto-backup settings

### 7. Test Backup & Restore

1. Tap **Backup Now** to upload your database to Google Drive
2. Check Google Drive - you should see a folder named `LifeRhythm_Backups`
3. The folder will contain files like `liferhythm_backup_2025-10-18T10-30-45.db`

## Troubleshooting

### "Sign in failed" Error

- **Android:** Make sure your SHA-1 fingerprint is correct
- **iOS:** Verify the URL scheme is correctly configured
- **Web:** Check that the client ID is correct in `index.html`

### "API has not been used in project" Error

- Make sure you enabled the Google Drive API in your Google Cloud project
- Wait a few minutes after enabling the API

### "Access blocked" Error

- Add your Google account as a test user in OAuth consent screen
- If the app is in testing mode, only test users can sign in

### OAuth Consent Screen "Needs Verification"

- For personal use, you can keep it in testing mode
- Add yourself and any testers as test users
- No verification is needed for testing

## Security Notes

1. **Never commit credentials to Git:**
   - OAuth client secrets should not be in your repository
   - For mobile apps, credentials are managed by Google Play/App Store

2. **API Key Restrictions:**
   - In Google Cloud Console, restrict your API keys by:
     - Application (Android/iOS bundle ID)
     - IP address (for servers)

3. **Scopes:**
   - The app only requests minimal scopes:
     - `drive.file` - Only access files created by the app
     - `drive.appdata` - App-specific hidden folder

## Features Implemented

✅ Google Sign-In authentication
✅ Manual backup to Google Drive
✅ Manual restore from Google Drive
✅ Auto-backup with configurable frequency
✅ Backup history viewer
✅ Delete old backups
✅ Database size display
✅ Last backup timestamp

## File Structure

```
lib/
├── services/
│   ├── google_drive_service.dart   # Google Drive API integration
│   ├── backup_service.dart          # Backup/restore logic
│   └── database_service.dart        # Database operations
└── screens/
    ├── backup_settings_screen.dart  # Backup UI
    └── settings_screen.dart         # Main settings
```

## Need Help?

- [Google Sign-In for Flutter Documentation](https://pub.dev/packages/google_sign_in)
- [Google Drive API Documentation](https://developers.google.com/drive/api/guides/about-sdk)
- [OAuth 2.0 Setup](https://support.google.com/cloud/answer/6158849)
