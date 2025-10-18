# GitHub Actions Setup Guide

## 🚀 Automatic Android Builds with GitHub Actions

This guide will help you set up GitHub Actions to automatically build your Android app whenever you push code.

---

## ✅ What You Get

Once configured, GitHub Actions will:
- ✅ Automatically build Android AAB (for Play Store) and APK (for testing)
- ✅ Run tests and code analysis
- ✅ Upload build artifacts you can download
- ✅ Create GitHub releases when you tag a version
- ✅ Build on GitHub's servers (no local Android SDK needed!)

---

## 🔐 Step 1: Prepare Your Keystore for GitHub

We need to convert your keystore to base64 so it can be stored as a GitHub secret.

### 1.1 Convert Keystore to Base64

Run this command:

```bash
base64 -w 0 ~/keystores/liferhythm-release-key.jks > ~/keystore-base64.txt
```

This creates a text file with your keystore encoded in base64.

### 1.2 Copy the Base64 String

```bash
cat ~/keystore-base64.txt
```

Copy the **entire output** (it will be a very long string). You'll need this in the next step.

⚠️ **IMPORTANT:** After you're done, delete this file for security:
```bash
rm ~/keystore-base64.txt
```

---

## 🔑 Step 2: Add Secrets to GitHub

Now we need to add your keystore and passwords as GitHub secrets.

### 2.1 Go to Your Repository Settings

1. Open your repository: https://github.com/NotYuSheng/LifeRhythm
2. Click **Settings** (top menu)
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**

### 2.2 Add These 4 Secrets

Add each secret one by one:

#### Secret 1: KEYSTORE_BASE64
- **Name:** `KEYSTORE_BASE64`
- **Value:** Paste the entire base64 string you copied earlier
- Click **Add secret**

#### Secret 2: KEYSTORE_PASSWORD
- **Name:** `KEYSTORE_PASSWORD`
- **Value:** Your keystore password (the one you created with keytool)
- Click **Add secret**

#### Secret 3: KEY_PASSWORD
- **Name:** `KEY_PASSWORD`
- **Value:** Your key password (same as keystore password if you pressed Enter)
- Click **Add secret**

#### Secret 4: KEY_ALIAS
- **Name:** `KEY_ALIAS`
- **Value:** `liferhythm-key-alias`
- Click **Add secret**

### 2.3 Verify Secrets

You should see 4 secrets listed:
- ✅ KEYSTORE_BASE64
- ✅ KEYSTORE_PASSWORD
- ✅ KEY_PASSWORD
- ✅ KEY_ALIAS

---

## 📤 Step 3: Push the Workflow to GitHub

Now let's commit and push the GitHub Actions workflow:

```bash
# Add the workflow file
git add .github/workflows/android-release.yml

# Commit
git commit -m "ci: Add GitHub Actions workflow for Android builds"

# Push to your branch
git push origin feat/ui-improvements
```

---

## 🎯 Step 4: Trigger a Build

You have 3 ways to trigger a build:

### Option A: Merge to Main Branch (Recommended)

When you merge your `feat/ui-improvements` branch to `main`, it will automatically build.

### Option B: Manual Trigger

1. Go to https://github.com/NotYuSheng/LifeRhythm/actions
2. Click **Build Android Release** workflow
3. Click **Run workflow**
4. Select your branch
5. Click **Run workflow**

### Option C: Create a Git Tag

```bash
git tag v1.0.0
git push origin v1.0.0
```

This will build AND create a GitHub release!

---

## 📥 Step 5: Download Your Built App

Once the workflow runs:

1. Go to https://github.com/NotYuSheng/LifeRhythm/actions
2. Click on the latest **Build Android Release** run
3. Scroll down to **Artifacts** section
4. Download:
   - `app-release-1.0.0+1.aab` - For Google Play Store
   - `app-release-1.0.0+1.apk` - For testing on devices

---

## 🔄 Workflow Behavior

The workflow will run when:
- ✅ You push to `main` branch
- ✅ You push to any `release/*` branch
- ✅ You create a tag like `v1.0.0`
- ✅ You manually trigger it from Actions tab

The workflow will:
1. Check out your code
2. Set up Flutter and Java
3. Run `flutter pub get`
4. Run `flutter analyze` (check for errors)
5. Run `flutter test` (run your tests)
6. Decode the keystore from base64
7. Build the AAB (for Play Store)
8. Build the APK (for testing)
9. Upload both as downloadable artifacts
10. Create a GitHub release (if you pushed a tag)

---

## 📊 Build Status Badge

Add a build status badge to your README.md:

```markdown
![Build Status](https://github.com/NotYuSheng/LifeRhythm/actions/workflows/android-release.yml/badge.svg)
```

This shows whether your latest build passed or failed.

---

## 🐛 Troubleshooting

### Build Fails: "Secret not found"

Make sure all 4 secrets are added:
- KEYSTORE_BASE64
- KEYSTORE_PASSWORD
- KEY_PASSWORD
- KEY_ALIAS

### Build Fails: "Invalid keystore format"

The base64 encoding might have failed. Try:
```bash
base64 ~/keystores/liferhythm-release-key.jks | tr -d '\n' > ~/keystore-base64.txt
```

### Tests Fail

If you don't have tests yet, you can modify the workflow to skip tests:
```yaml
- name: Run Flutter tests
  run: flutter test --no-pub || true  # Add || true to ignore test failures
```

### Build Takes Too Long

First builds take 5-10 minutes. Subsequent builds are faster (2-3 minutes) due to caching.

---

## 🎯 Next Steps After Build Succeeds

Once you have the AAB file:

1. ✅ Download the `app-release-*.aab` file
2. ✅ Go to Google Play Console
3. ✅ Create a new app (if not done yet)
4. ✅ Upload the AAB to Production or Testing track
5. ✅ Complete the store listing
6. ✅ Submit for review

Follow the main deployment guide: [GOOGLE_PLAY_DEPLOYMENT.md](GOOGLE_PLAY_DEPLOYMENT.md)

---

## 🔄 Updating Your App

When you want to release a new version:

### 1. Update Version in pubspec.yaml

```yaml
version: 1.1.0+2  # Increment version
```

### 2. Commit and Push

```bash
git add pubspec.yaml
git commit -m "chore: Bump version to 1.1.0"
git push origin main
```

### 3. (Optional) Create a Git Tag

```bash
git tag v1.1.0
git push origin v1.1.0
```

This will automatically:
- Build the new version
- Create a GitHub release with the APK/AAB attached

---

## 💡 Pro Tips

### Tip 1: Test Before Merging to Main

Create a separate workflow for pull requests that only runs tests:

```yaml
name: PR Tests
on: [pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter test
```

### Tip 2: Build Only on Release Tags

If you don't want to build on every push, change the trigger:

```yaml
on:
  push:
    tags:
      - 'v*.*.*'  # Only build on version tags
```

### Tip 3: Notify on Build Completion

Add Slack/Discord notifications when builds succeed or fail.

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
- [Subosito Flutter Action](https://github.com/subosito/flutter-action)

---

## ✅ Quick Reference Commands

```bash
# Convert keystore to base64
base64 -w 0 ~/keystores/liferhythm-release-key.jks > ~/keystore-base64.txt

# View base64 (to copy)
cat ~/keystore-base64.txt

# Delete base64 file (after copying)
rm ~/keystore-base64.txt

# Push workflow to GitHub
git add .github/
git commit -m "ci: Add GitHub Actions workflow"
git push

# Create version tag
git tag v1.0.0
git push origin v1.0.0

# View workflow runs
# Go to: https://github.com/NotYuSheng/LifeRhythm/actions
```

---

## 🎉 You're All Set!

Once you complete these steps, you'll have:
- ✅ Automatic builds on every push
- ✅ Downloadable AAB/APK files
- ✅ Professional CI/CD pipeline
- ✅ No need for local Android SDK

Happy deploying! 🚀
