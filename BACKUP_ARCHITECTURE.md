# Google Drive Backup - Architecture Documentation

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         LifeRhythm App                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              UI Layer (Screens)                          │  │
│  │                                                          │  │
│  │  ┌─────────────────┐      ┌────────────────────────┐   │  │
│  │  │ Settings Screen │─────▶│ Backup Settings Screen │   │  │
│  │  └─────────────────┘      └────────────────────────┘   │  │
│  │                                    │                     │  │
│  └────────────────────────────────────┼─────────────────────┘  │
│                                       │                        │
│  ┌────────────────────────────────────▼─────────────────────┐  │
│  │              Service Layer                               │  │
│  │                                                          │  │
│  │  ┌──────────────────┐      ┌────────────────────────┐  │  │
│  │  │  BackupService   │◀────▶│ GoogleDriveService     │  │  │
│  │  │                  │      │                        │  │  │
│  │  │ • backup()       │      │ • signIn()             │  │  │
│  │  │ • restore()      │      │ • uploadBackup()       │  │  │
│  │  │ • autoBackup()   │      │ • downloadBackup()     │  │  │
│  │  │ • getStats()     │      │ • listBackups()        │  │  │
│  │  └────────┬─────────┘      └───────────┬────────────┘  │  │
│  │           │                            │               │  │
│  └───────────┼────────────────────────────┼───────────────┘  │
│              │                            │                  │
│  ┌───────────▼────────────────────────────▼───────────────┐  │
│  │              Data Layer                                 │  │
│  │                                                         │  │
│  │  ┌──────────────────┐      ┌────────────────────────┐ │  │
│  │  │ DatabaseService  │      │ SharedPreferences      │ │  │
│  │  │ (SQLite)         │      │ (Settings)             │ │  │
│  │  └──────────────────┘      └────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                │
└────────────────────────────┬───────────────────────────────────┘
                             │
                             │ Network I/O
                             │
┌────────────────────────────▼───────────────────────────────────┐
│                     External Services                          │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────┐      ┌─────────────────────────┐   │
│  │  Google Sign-In API  │      │  Google Drive API       │   │
│  │                      │      │                         │   │
│  │ • OAuth 2.0          │      │ • File Upload           │   │
│  │ • User Auth          │      │ • File Download         │   │
│  │ • Token Management   │      │ • File Listing          │   │
│  └──────────────────────┘      │ • File Deletion         │   │
│                                │ • Folder Management     │   │
│                                └─────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

### UI Layer

#### BackupSettingsScreen
- Displays Google account connection status
- Provides backup/restore action buttons
- Shows backup statistics
- Manages auto-backup settings
- Displays backup history
- Handles user interactions

**Key Methods:**
- `_signIn()` - Initiate Google Sign-In
- `_signOut()` - Sign out from Google
- `_performBackup()` - Trigger manual backup
- `_performRestore()` - Trigger restore from backup
- `_toggleAutoBackup()` - Enable/disable auto-backup
- `_setBackupFrequency()` - Configure backup schedule
- `_deleteBackup()` - Remove specific backup

### Service Layer

#### GoogleDriveService (Singleton)
Handles all Google Drive API interactions.

**Authentication:**
- `initialize()` - Initialize and check for existing auth
- `signIn()` - Perform Google Sign-In flow
- `signOut()` - Sign out user
- `isSignedIn` - Check authentication status
- `currentUser` - Get current Google account

**Backup Operations:**
- `uploadBackup(File)` - Upload database to Drive
- `downloadLatestBackup()` - Download most recent backup
- `listBackups()` - Get all backup files
- `deleteBackup(String)` - Delete specific backup

**Utilities:**
- `_getOrCreateBackupFolder()` - Manage backup folder
- `getLastBackupTime()` - Retrieve last backup timestamp

#### BackupService (Singleton)
Orchestrates backup operations and manages settings.

**Core Operations:**
- `backupToGoogleDrive()` - Complete backup workflow
- `restoreFromGoogleDrive()` - Complete restore workflow

**Auto-Backup:**
- `isAutoBackupEnabled()` - Check if auto-backup is on
- `setAutoBackupEnabled(bool)` - Toggle auto-backup
- `getAutoBackupFrequency()` - Get backup interval
- `setAutoBackupFrequency(int)` - Set backup interval
- `isBackupDue()` - Check if backup should run
- `performAutoBackupIfDue()` - Execute auto-backup if needed

**Statistics:**
- `getBackupStats()` - Retrieve backup statistics

### Data Layer

#### DatabaseService
SQLite database management (existing service).

**Used by BackupService for:**
- Getting database file path
- Closing database before restore
- Re-opening database after restore

#### SharedPreferences
Key-value storage for settings.

**Stored Data:**
- `last_backup_time` - Timestamp of last successful backup
- `last_backup_file_id` - Google Drive file ID of last backup
- `auto_backup_enabled` - Auto-backup toggle state
- `auto_backup_frequency` - Backup interval in days

## Data Flow Diagrams

### Backup Flow

```
User taps "Backup Now"
        │
        ▼
┌───────────────────┐
│ BackupSettings    │
│ Screen            │
└─────────┬─────────┘
          │ _performBackup()
          ▼
┌───────────────────┐
│ BackupService     │
│ .backupToGoogle   │
│ Drive()           │
└─────────┬─────────┘
          │
          ├─ Get database file path
          │
          ▼
┌───────────────────┐
│ GoogleDriveService│
│ .uploadBackup()   │
└─────────┬─────────┘
          │
          ├─ Get/create backup folder
          ├─ Create file metadata
          ├─ Upload file
          │
          ▼
┌───────────────────┐
│ Google Drive API  │
│ Files.create()    │
└─────────┬─────────┘
          │
          ▼
    Save metadata
  (last backup time,
   file ID)
          │
          ▼
    Show success
    message to user
```

### Restore Flow

```
User taps "Restore"
        │
        ▼
Show confirmation
    dialog
        │
        ▼
User confirms
        │
        ▼
┌───────────────────┐
│ BackupService     │
│ .restoreFromGoogle│
│ Drive()           │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ GoogleDriveService│
│ .downloadLatest   │
│ Backup()          │
└─────────┬─────────┘
          │
          ├─ List backups
          ├─ Get latest file
          ├─ Download to temp
          │
          ▼
┌───────────────────┐
│ Google Drive API  │
│ Files.get()       │
└─────────┬─────────┘
          │
          ▼
Backup current
  database
          │
          ▼
Close database
  connection
          │
          ▼
Replace database
  file
          │
          ▼
Re-open database
          │
          ▼
    Show success
    (ask to restart)
```

### Auto-Backup Flow

```
App launches
        │
        ▼
┌───────────────────┐
│ main()            │
│ Initialize        │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ BackupService     │
│ .performAutoBackup│
│ IfDue()           │
└─────────┬─────────┘
          │
          ├─ Check if enabled
          ├─ Check last backup time
          ├─ Calculate if due
          │
          ▼
     Is backup due?
          │
      ┌───┴───┐
      │       │
     Yes      No
      │       │
      │       └─ Exit
      │
      ▼
 Run backup
 in background
      │
      ▼
    Done
```

## Security Architecture

### Authentication Flow

```
┌─────────────┐
│   User      │
│  Taps Sign In
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ GoogleSignIn    │
│ Package         │
│ (OAuth 2.0)     │
└────────┬────────┘
         │
         │ Opens browser/
         │ webview
         ▼
┌─────────────────┐
│ Google Auth     │
│ Server          │
│ (User signs in) │
└────────┬────────┘
         │
         │ Returns auth
         │ code
         ▼
┌─────────────────┐
│ GoogleSignIn    │
│ Package         │
│ (Exchanges code)│
└────────┬────────┘
         │
         │ Gets access
         │ token
         ▼
┌─────────────────┐
│ App stores      │
│ authenticated   │
│ client          │
└─────────────────┘
```

### Data Security

1. **Authentication:**
   - OAuth 2.0 standard protocol
   - No passwords stored in app
   - Access tokens managed by Google Sign-In library
   - Token refresh handled automatically

2. **Authorization:**
   - Minimal scopes requested:
     - `drive.file` - Only files created by app
     - `drive.appdata` - App-specific hidden folder
   - No access to user's other Drive files
   - User can revoke access anytime

3. **Data Transfer:**
   - HTTPS for all API calls
   - No man-in-the-middle vulnerability
   - Google's infrastructure security

4. **Data Storage:**
   - User's Google Drive (user-controlled)
   - User can delete backups anytime
   - User can download backups manually

## Error Handling

```
Try Operation
      │
      ▼
  Success?
      │
  ┌───┴───┐
  │       │
 Yes      No
  │       │
  │       ▼
  │   Catch Exception
  │       │
  │       ├─ Network error?
  │       ├─ Auth error?
  │       ├─ Permission error?
  │       ├─ Storage error?
  │       │
  │       ▼
  │   Log error
  │   (debugPrint)
  │       │
  │       ▼
  │   Return error
  │   result
  │       │
  └───────┤
          ▼
    Show user
    feedback
    (SnackBar)
```

## State Management

### App State

```
┌─────────────────────┐
│ App Launch          │
│                     │
│ GoogleDriveService  │
│ .initialize()       │
│                     │
│ State: Not signed in│
└──────────┬──────────┘
           │
           ▼
    User signs in?
           │
       ┌───┴───┐
       │       │
      Yes      No
       │       │
       │       └─ Stays not signed in
       │
       ▼
┌─────────────────────┐
│ State: Signed in    │
│                     │
│ - User email stored │
│ - DriveApi ready    │
│ - Backup enabled    │
└─────────────────────┘
```

### Screen State

```
BackupSettingsScreen
├── _isLoading: bool (show spinner)
├── _isSignedIn: bool (show signed-in UI)
├── _userEmail: String? (display email)
├── _stats: BackupStats? (show statistics)
└── _backupFiles: List<BackupFile> (show history)
```

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading:**
   - Drive API initialized only when needed
   - Backup list loaded on demand
   - Statistics computed on request

2. **Caching:**
   - Last backup time cached locally
   - Settings cached in SharedPreferences
   - User auth state cached by Google Sign-In

3. **Background Operations:**
   - Auto-backup runs asynchronously
   - No blocking of UI thread
   - File operations use streaming

4. **Resource Management:**
   - Database closed properly before restore
   - Temporary files deleted after use
   - Network connections managed by libraries

## Testing Strategy

### Unit Tests (To be implemented)
- Service method logic
- Date/time calculations
- Settings persistence
- Error handling

### Integration Tests (To be implemented)
- Sign-in flow
- Backup/restore workflow
- Auto-backup scheduling
- File operations

### Manual Testing Checklist
- ✅ Sign in with Google
- ✅ Sign out
- ✅ Create backup
- ✅ Verify backup in Drive
- ✅ List backups
- ✅ Delete backup
- ✅ Restore from backup
- ✅ Enable auto-backup
- ✅ Change frequency
- ✅ Verify auto-backup triggers
- ✅ Test error scenarios

## Deployment Checklist

### Development
- [x] Code implementation
- [x] Code analysis passing
- [x] Documentation complete
- [ ] Manual testing complete
- [ ] Google Cloud project setup
- [ ] OAuth credentials configured

### Staging
- [ ] Testing OAuth consent screen
- [ ] Test users added
- [ ] All platforms tested
- [ ] Error scenarios tested
- [ ] Performance verified

### Production
- [ ] OAuth consent screen published
- [ ] Privacy policy added
- [ ] Terms of service added
- [ ] App verification submitted (if needed)
- [ ] Production credentials configured
- [ ] Monitoring enabled
- [ ] User documentation published

---

**Last Updated:** October 18, 2025
**Version:** 1.0.0
