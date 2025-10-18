# Google Drive Backup - Quick Start Guide

## TL;DR - Get Started in 5 Minutes

This is a condensed guide to get Google Drive backup working quickly. For detailed information, see [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md).

## ⚠️ Platform Support

**Supported Platforms:** Android, iOS, Web
**Not Supported:** Linux, Windows, macOS desktop

For details, see [PLATFORM_SUPPORT.md](PLATFORM_SUPPORT.md)

## Prerequisites

- A Google account
- An Android device, iOS device, or web browser
- 5 minutes of your time

## Step 1: Create Google Cloud Project (2 minutes)

1. Go to: https://console.cloud.google.com/
2. Click **"New Project"** (top left, next to "Google Cloud")
3. Name it: `LifeRhythm`
4. Click **Create**

## Step 2: Enable Google Drive API (30 seconds)

1. In Google Cloud Console, go to: **APIs & Services > Library**
2. Search: `Google Drive API`
3. Click on it → Click **ENABLE**

## Step 3: Configure OAuth Consent (1 minute)

1. Go to: **APIs & Services > OAuth consent screen**
2. Choose: **External**
3. Fill in:
   - App name: `LifeRhythm`
   - User support email: (your email)
   - Developer contact: (your email)
4. Click **Save and Continue**
5. Click **Add or Remove Scopes**
6. Manually add these scopes:
   - `https://www.googleapis.com/auth/drive.file`
   - `https://www.googleapis.com/auth/drive.appdata`
7. Click **Update** → **Save and Continue**
8. Add test users: Add your email address
9. Click **Save and Continue**

## Step 4: Create OAuth Credentials (Platform-Specific)

### For Android Testing

1. Get your SHA-1 fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
   Copy the SHA-1 value (looks like: `AB:CD:EF:12:34:...`)

2. In Google Cloud Console: **APIs & Services > Credentials**
3. Click **Create Credentials > OAuth client ID**
4. Choose: **Android**
5. Fill in:
   - Name: `LifeRhythm Android`
   - Package name: `com.example.life_rhythm`
   - SHA-1: (paste the value from step 1)
6. Click **Create**

**Done!** Android needs no additional app configuration.

### For iOS Testing

1. In Google Cloud Console: **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose: **iOS**
4. Fill in:
   - Name: `LifeRhythm iOS`
   - Bundle ID: `com.example.lifeRhythm`
5. Click **Create**
6. Copy the **iOS URL scheme** (looks like: `com.googleusercontent.apps.123456-abc...`)

7. Edit `ios/Runner/Info.plist`, add before the last `</dict>`:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleTypeRole</key>
       <string>Editor</string>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>PUT-YOUR-IOS-URL-SCHEME-HERE</string>
       </array>
     </dict>
   </array>
   ```

### For Web Testing

1. In Google Cloud Console: **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose: **Web application**
4. Fill in:
   - Name: `LifeRhythm Web`
   - Authorized JavaScript origins: `http://localhost`
   - Authorized redirect URIs: `http://localhost`
5. Click **Create**
6. Copy the **Client ID**

7. Edit `web/index.html`, add in the `<head>` section:
   ```html
   <meta name="google-signin-client_id" content="YOUR-CLIENT-ID-HERE.apps.googleusercontent.com">
   ```

## Step 5: Test! (1 minute)

1. Run the app:
   ```bash
   flutter run
   ```

2. Navigate to: **Settings → Backup & Sync**

3. Tap **Sign in with Google**

4. Complete the sign-in flow

5. Tap **Backup Now**

6. Check your Google Drive → You should see a `LifeRhythm_Backups` folder!

## Troubleshooting

### "Sign in failed"
- **Android**: Check SHA-1 fingerprint is correct
- **iOS**: Check URL scheme in Info.plist
- **All**: Make sure you added yourself as a test user

### "API has not been used in project"
- Wait 2-3 minutes after enabling the Google Drive API
- Try signing in again

### "Access blocked"
- Go to OAuth consent screen
- Add your Google account as a test user
- Your app is in "Testing" mode - only test users can sign in

### Still stuck?
See detailed troubleshooting in [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md)

## What's Next?

Once you've tested:

1. **Explore features:**
   - Create multiple backups
   - View backup history
   - Delete old backups
   - Test restore functionality
   - Enable auto-backup

2. **For production:**
   - Follow the production deployment section in [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md)
   - Request OAuth verification (if making app public)
   - Update OAuth credentials with release keystore

## Summary of What You Built

✨ **Features now available:**
- Google Sign-In authentication
- One-tap backup to Google Drive
- Restore from backup
- Auto-backup with scheduling
- Backup history management
- Local database protection

🎉 **Congratulations!** Your app now has cloud backup!

---

**Need help?** See [GOOGLE_DRIVE_SETUP.md](GOOGLE_DRIVE_SETUP.md) for detailed documentation.
