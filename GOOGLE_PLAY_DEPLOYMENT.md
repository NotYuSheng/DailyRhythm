# Google Play Store Deployment Guide for LifeRhythm

## 📱 Complete Guide to Publishing Your Flutter App

This guide will walk you through deploying LifeRhythm to the Google Play Store.

---

## ✅ Prerequisites

Before you start, ensure you have:
- [ ] A Google Play Console account ($25 one-time registration fee)
- [ ] App icon prepared (512x512 PNG for Play Store)
- [ ] Screenshots of your app (at least 2 required)
- [ ] Privacy Policy URL (required for apps handling user data)
- [ ] App description and promotional text written

---

## 📋 Step-by-Step Deployment Process

### **Step 1: Create a Google Play Console Account**

1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with your Google account
3. Pay the $25 one-time registration fee
4. Complete the account setup (developer name, contact info, etc.)
5. Accept the Developer Distribution Agreement

---

### **Step 2: Generate a Keystore for App Signing**

⚠️ **IMPORTANT:** Keep your keystore file safe! You'll need it for ALL future updates.

Run these commands from your project root:

```bash
# Create a keystore directory (this will be gitignored)
mkdir -p ~/keystores

# Generate the keystore
keytool -genkey -v -keystore ~/keystores/liferhythm-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias liferhythm-key-alias

# You'll be prompted for:
# - Keystore password (CREATE A STRONG PASSWORD - SAVE IT!)
# - Key password (can be the same as keystore password)
# - Your name, organization, city, state, country
```

**CRITICAL:** Write down these details and store them securely:
- Keystore password: `_______________`
- Key alias: `liferhythm-key-alias`
- Key password: `_______________`
- Keystore location: `~/keystores/liferhythm-release-key.jks`

---

### **Step 3: Configure Signing in Your Flutter Project**

**3.1** Create a key properties file (this file will NOT be committed to git):

```bash
cat > android/key.properties << 'EOF'
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=liferhythm-key-alias
storeFile=/home/ubuntu/keystores/liferhythm-release-key.jks
EOF
```

Replace `YOUR_KEYSTORE_PASSWORD` and `YOUR_KEY_PASSWORD` with your actual passwords.

**3.2** Update `.gitignore` to exclude the key properties file:

The file should already have this, but verify:
```
**/android/key.properties
```

**3.3** Update `android/app/build.gradle.kts`:

The file currently has debug signing. We need to add release signing.

Add this code BEFORE the `android {` block:

```kotlin
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}
```

Then update the `android {}` block to include signing configs:

```kotlin
android {
    namespace = "com.liferhythm.liferhythm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // ... existing config ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

---

### **Step 4: Prepare App Assets**

**4.1 App Icon** (512x512 PNG for Play Store)

Your app needs a high-resolution icon for the Play Store listing.

**4.2 Screenshots** (at least 2, recommended 4-8)

Take screenshots of:
- Journal screen with sample data
- Calendar view
- **Metrics dashboard** (your new feature!)
- Settings screen

Use `flutter screenshot` or run the app and capture manually.

**4.3 Feature Graphic** (1024x500 PNG)

Create a promotional banner for your app listing.

**4.4 Privacy Policy**

Your app collects mood, sleep, exercise data, so you MUST have a privacy policy.

Create one at [Privacy Policy Generator](https://app-privacy-policy-generator.firebaseapp.com/) or similar.

Host it on:
- GitHub Pages (free)
- Your own website
- Google Docs (set to public)

---

### **Step 5: Update App Metadata**

**5.1** Verify `pubspec.yaml` version:

Current version: `1.0.0+1`
- `1.0.0` = Version name (shown to users)
- `+1` = Version code (internal, must increment with each release)

**5.2** Update app permissions in `AndroidManifest.xml`:

Your app currently doesn't request special permissions, which is good!
If you add Google Drive sync, you'll need INTERNET permission (already implied).

---

### **Step 6: Build the Release Bundle**

Google Play requires an **Android App Bundle (AAB)** format, not APK.

```bash
# Clean the project first
flutter clean

# Get dependencies
flutter pub get

# Build the release bundle
flutter build appbundle --release

# The bundle will be created at:
# build/app/outputs/bundle/release/app-release.aab
```

**Verify the build:**
```bash
ls -lh build/app/outputs/bundle/release/app-release.aab
```

You should see a file around 15-25 MB.

---

### **Step 7: Test the Release Build**

Before uploading to Play Store, test locally:

```bash
# Build a release APK for testing
flutter build apk --release

# Install on a connected Android device
flutter install --release

# Or use bundletool to test the AAB
# (requires Java)
```

**Test thoroughly:**
- All screens work correctly
- Data persistence (database)
- Dark mode switching
- Google Drive backup (if enabled)
- Metrics tab visualizations

---

### **Step 8: Create a New App in Play Console**

1. Go to [Google Play Console](https://play.google.com/console)
2. Click **Create app**
3. Fill in details:
   - **App name:** LifeRhythm
   - **Default language:** English (United States)
   - **App or game:** App
   - **Free or paid:** Free
   - **User program policies:** Accept declarations

4. Complete the setup checklist:

#### **a) App Access**
- Declare if your app requires login or special access
- For LifeRhythm: "All functionality is available without restrictions"

#### **b) Ads**
- Does your app contain ads? → No (unless you've added ads)

#### **c) Content Rating**
- Fill out the questionnaire
- LifeRhythm should get "Everyone" or "Everyone 10+" rating

#### **d) Target Audience**
- Select age groups: 18+ recommended (health/mood tracking)

#### **e) News Apps**
- Not applicable

#### **f) COVID-19 Contact Tracing**
- Not applicable

#### **g) Data Safety**
- **Critical section!** Declare what data you collect:
  - Sleep data → Yes, collected
  - Mood data → Yes, collected
  - Exercise data → Yes, collected
  - Stored locally → Yes
  - Encrypted → Declare SQLite encryption if enabled
  - Can be deleted → Yes (users can delete entries)
  - Shared with third parties → Only if using Google Drive backup

#### **h) Privacy Policy**
- Provide your privacy policy URL

---

### **Step 9: Set Up the Store Listing**

#### **Product Details:**
- **App name:** LifeRhythm
- **Short description** (80 chars max):
  ```
  Track your daily rhythm: sleep, mood, exercise, and activities with beautiful metrics
  ```

- **Full description** (4000 chars max):
  ```
  LifeRhythm - Your Personal Life Metrics Dashboard

  Take control of your daily rhythms with LifeRhythm, a beautiful and minimalist app designed to help you track and understand your life patterns.

  ✨ FEATURES

  📔 Daily Journal
  • Track sleep with detailed wake/sleep times and nap tracking
  • Log mood with 5-level rating system and emojis
  • Record exercises (running, weight lifting) with detailed metrics
  • Log meals with pricing and calorie tracking
  • Tag daily activities from custom categories

  📊 Comprehensive Metrics Dashboard
  • Beautiful charts showing sleep patterns over time
  • Mood distribution with percentage breakdowns
  • Exercise progress tracking
  • Activity frequency analysis
  • Auto-generated insights based on your data
  • Multiple time ranges: 7 days, 30 days, month, year, all time

  📅 Calendar View
  • See your mood history at a glance
  • Jump to any day to review or edit entries
  • Emoji indicators show mood for each day

  🎨 Beautiful Monochrome Design
  • Clean, minimalist interface
  • Full dark mode support
  • Rhythmic spacing and smooth animations
  • Distraction-free experience

  💾 Data Management
  • All data stored locally on your device
  • CSV export for backup and analysis
  • CSV import to restore data
  • Google Drive backup and sync (optional)

  🔒 Privacy First
  • No account required
  • All data stays on your device
  • No ads, no tracking, no data collection
  • Open source (link to GitHub)

  Whether you're optimizing your sleep schedule, tracking your mood patterns, or monitoring your exercise progress, LifeRhythm gives you the insights you need to understand your daily rhythms.

  Perfect for:
  • Sleep tracking and optimization
  • Mood journaling and mental health awareness
  • Exercise and fitness tracking
  • Daily routine optimization
  • Life metrics enthusiasts
  ```

#### **Graphics:**
- App icon (512x512)
- Feature graphic (1024x500)
- Phone screenshots (2-8)
- 7-inch tablet screenshots (optional)
- 10-inch tablet screenshots (optional)

#### **Categorization:**
- **Category:** Health & Fitness
- **Tags:** health, fitness, tracking, journal, mood, sleep

#### **Contact Details:**
- Email: your@email.com
- Website: https://github.com/NotYuSheng/LifeRhythm (or your own)

---

### **Step 10: Upload the App Bundle**

1. Go to **Production** → **Create new release**
2. Upload `build/app/outputs/bundle/release/app-release.aab`
3. Google Play will analyze it and show you:
   - APK sizes for different devices
   - Supported devices
   - Any warnings or errors

4. Add release notes:
   ```
   Initial release of LifeRhythm!

   Features:
   • Daily journal for sleep, mood, exercise, meals, and activities
   • Comprehensive metrics dashboard with beautiful charts
   • Calendar view with mood indicators
   • Dark mode support
   • CSV export/import
   • Google Drive backup
   ```

5. Review and roll out:
   - Start with **Internal testing** (test with small group)
   - Then **Closed testing** (beta testers)
   - Finally **Production** (public release)

---

### **Step 11: Internal Testing (Recommended First Step)**

Before public release, test with a small group:

1. Create an **Internal testing track**
2. Add email addresses of testers (up to 100)
3. Upload the AAB to internal testing
4. Share the testing link with your testers
5. Collect feedback and fix bugs
6. Repeat until stable

**Advantages:**
- Fast review (usually minutes)
- Find bugs before public release
- Get real user feedback

---

### **Step 12: Submit for Review**

1. Complete all required sections (checklist in Play Console)
2. Click **Submit for review**
3. Wait for Google's review (usually 1-7 days)
4. Check your email for approval or rejection

**Common rejection reasons:**
- Missing privacy policy
- Data safety form incomplete
- Screenshots don't match app functionality
- Crashes on certain devices

---

## 🚀 Post-Launch Checklist

After approval:
- [ ] Test download from Play Store on real device
- [ ] Monitor crash reports in Play Console
- [ ] Respond to user reviews
- [ ] Track metrics (downloads, retention, ratings)
- [ ] Plan updates based on feedback

---

## 🔄 Updating the App

When you want to release an update:

1. **Update version in `pubspec.yaml`:**
   ```yaml
   version: 1.1.0+2
   # Version name: 1.1.0 (shown to users)
   # Version code: +2 (must be higher than previous)
   ```

2. **Build new bundle:**
   ```bash
   flutter build appbundle --release
   ```

3. **Upload to Play Console:**
   - Production → Create new release
   - Upload new AAB
   - Add release notes
   - Roll out

---

## 📊 Version Management

| Version Name | Version Code | Release Date | Notes |
|--------------|--------------|--------------|-------|
| 1.0.0        | 1            | TBD          | Initial release |
| 1.1.0        | 2            | TBD          | Metrics dashboard |

**Version Naming Convention:**
- **Major** (1.x.x): Breaking changes, major features
- **Minor** (x.1.x): New features, improvements
- **Patch** (x.x.1): Bug fixes, small updates

---

## 🔐 Security Best Practices

1. **NEVER commit these files to git:**
   - `android/key.properties`
   - `~/keystores/liferhythm-release-key.jks`
   - Any files containing passwords

2. **Backup your keystore:**
   - Store in multiple secure locations
   - Consider using a password manager
   - If you lose it, you can NEVER update your app!

3. **Use strong passwords:**
   - Minimum 12 characters
   - Mix of letters, numbers, symbols

---

## 🐛 Troubleshooting

### Build fails with "Execution failed for task ':app:lintVitalRelease'"
```bash
# Add this to android/app/build.gradle.kts in android {} block:
lintOptions {
    checkReleaseBuilds = false
}
```

### "You uploaded an APK that is debuggable"
- Make sure you're building with `--release` flag
- Check that `signingConfig` is set to release, not debug

### "The APK is not signed"
- Verify `key.properties` file exists and has correct paths
- Check keystore file exists at the specified location

### App crashes on some devices
- Test on multiple Android versions
- Check Firebase Crashlytics for crash reports
- Enable ProGuard rules if using native code

---

## 📚 Additional Resources

- [Flutter Deployment Documentation](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android App Bundle Format](https://developer.android.com/guide/app-bundle)
- [Play Console Policies](https://play.google.com/about/developer-content-policy/)

---

## 💡 Tips for Success

1. **Write a great app description** - Explain benefits, not just features
2. **Use high-quality screenshots** - Show the app in action with sample data
3. **Respond to reviews** - Shows you care about users
4. **Update regularly** - Keeps app relevant and ranking high
5. **Monitor analytics** - Use Play Console data to improve
6. **A/B test** - Try different descriptions/screenshots
7. **Localize** - Translate to reach more users

---

## ✅ Quick Reference Commands

```bash
# Generate keystore
keytool -genkey -v -keystore ~/keystores/liferhythm-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias liferhythm-key-alias

# Build release bundle
flutter build appbundle --release

# Build release APK (for testing)
flutter build apk --release

# Check bundle size
ls -lh build/app/outputs/bundle/release/app-release.aab

# Clean build
flutter clean && flutter pub get
```

---

**🎉 Good luck with your launch!**

If you encounter any issues during deployment, check the troubleshooting section or consult the Flutter/Google Play documentation.
