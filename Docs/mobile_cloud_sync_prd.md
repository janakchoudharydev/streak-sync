# Product Requirements Document (PRD): Mobile Cloud Sync (Android & iOS)

---

## 1. Executive Summary & Objective

### 1.1 Objective
Extend the cloud synchronization architecture established on macOS to **Android** and **iOS** mobile platforms. Ensure seamless, real-time, and background bidirectional data sync between Mac desktop and mobile devices for habits, completions, categories, notes, focus sessions, and todos, while maintaining a strict **offline-first** design and a **$0.00/month** infrastructure cost.

### 1.2 Target Experience
* A user marks a habit complete or creates a todo on their Mac.
* When they open Streak on their iPhone or Android phone, their progress is already synced.
* If either device goes offline (e.g., airplane mode), mutations are stored locally and automatically dispatched once connectivity resumes.

---

## 2. Current State & Gap Analysis

Because the Flutter Dart layer was built with platform-agnostic abstractions, the core sync components are already available in the codebase:
- `SyncQueue` (`client/lib/core/sync/sync_queue.dart`): Hive-backed offline mutation queue.
- `SyncWorker` (`client/lib/core/sync/sync_worker.dart`): LWW conflict resolution & change absorption.
- `SyncController` (`client/lib/core/sync/sync_controller.dart`): Reactive state provider.
- `CloudSyncPage` (`client/lib/features/settings/pages/cloud_sync_page.dart`): Auth & Sync status UI.

### Native Mobile Gaps Identified

| Platform | Component | Current State | Required Change |
| :--- | :--- | :--- | :--- |
| **Android** | `AndroidManifest.xml` | Deliberately stripped `ACCESS_NETWORK_STATE` and lacks `INTERNET` permission (F-Droid legacy). | Add `<uses-permission android:name="android.permission.INTERNET"/>` and restore `ACCESS_NETWORK_STATE`. |
| **Android** | Network Security | Android 9+ blocks cleartext HTTP (`http://192.168.x.x`). | Configure `network_security_config.xml` for local IP dev testing, or connect to public HTTPS (Vercel). |
| **iOS** | `Info.plist` & Runner | Missing Background Modes (`fetch`, `processing`). | Add `UIBackgroundModes` for background sync when app is suspended. |
| **iOS** | Security & ATS | App Transport Security blocks arbitrary HTTP by default. | Require HTTPS (Vercel) or whitelist local IP under `NSAppTransportSecurity`. |
| **Both** | Network Host | `localhost:3000` is loopback to the phone itself. | Default to public Vercel production API URL (`https://your-sync-api.vercel.app`) with custom URL override. |

---

## 3. Product & User Experience Requirements

### 3.1 Authentication & Onboarding
1. **Access Point**: Accessible via **Settings** -> **Cloud Sync** across all 3 visual styles (Classic, Minimal, Express).
2. **Minimalist Form**: Email & Password with a single toggle between "Sign In" and "Create Account".
3. **Session Persistence**: JWT securely preserved across device reboots and app updates using `flutter_secure_storage` (Android EncryptedSharedPreferences / iOS Keychain).
4. **Multi-Device Account Sharing**: The same credentials log into both Mac and mobile devices.

### 3.2 Bidirectional Sync Behavior
1. **Push on Mutation**: Whenever a habit, todo, or note is modified locally, the mutation is immediately recorded in `SyncQueue` and dispatched asynchronously.
2. **Pull on Resume**: When the mobile app is brought to the foreground (`AppLifecycleState.resumed`), trigger an automatic pull delta request.
3. **Periodic Sync**: Automatically trigger sync every 5 minutes while the app is active.
4. **Non-Blocking UI**: Sync operations must never show modal blockers or spinners that prevent user interaction.
5. **Conflict Resolution**: Last-Write-Wins (LWW) based on UTC timestamps. Multi-device habit completions are deep-merged (no lost checkboxes).

### 3.3 Offline-First Principles
* The app must start and be 100% interactive without an active internet connection.
* If a sync request times out or encounters network disconnection:
  * Fail silently into the local queue.
  * No disruptive error dialogs (status icon indicates offline).
  * Automatically flush queue on next network reconnect.

---

## 4. Technical Architecture for Mobile

```mermaid
graph TD
    subgraph Mobile Device (Android / iOS)
        UI[Streak Flutter UI]
        LS[LocalStore Hive]
        SQ[SyncQueue Box]
        SW[SyncWorker Engine]
        SS[Secure Storage Keychain/Keystore]
        AL[App Lifecycle Observer]
    end

    subgraph Free Tier Cloud Backend
        Vercel[Vercel Serverless API /api/sync]
        DB[(Supabase PostgreSQL / Atlas)]
    end

    subgraph Mac Desktop
        MacApp[Streak macOS App]
    end

    UI -->|Write Habit/Todo| LS
    LS -->|Auto Queue| SQ
    AL -->|On App Resume| SW
    SW -->|Read Queue| SQ
    SW -->|Read JWT| SS
    SW -->|HTTPS POST| Vercel
    Vercel -->|LWW Persist| DB
    MacApp -->|HTTPS POST| Vercel
    Vercel -->|Return Delta| SW
    SW -->|Absorb Changes| LS
    LS -->|Notify| UI
```

---

## 5. Mobile Platform Implementation Specifications

### 5.1 Android Configuration
1. **Permissions (`android/app/src/main/AndroidManifest.xml`)**:
   Add internet permissions inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
   ```
   *Remove or comment out the existing `<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" tools:node="remove" />`.*

2. **Network Security Config (`android/app/src/main/res/xml/network_security_config.xml`)**:
   Allow cleartext traffic to local LAN IPs for local testing:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <network-security-config>
       <base-config cleartextTrafficPermitted="true">
           <trust-anchors>
               <certificates src="system" />
           </trust-anchors>
       </base-config>
   </network-security-config>
   ```

3. **ProGuard / R8 Rules (`android/app/proguard-rules.pro`)**:
   Ensure `flutter_secure_storage` and `crypto` serialization classes are preserved during release APK minification.

---

### 5.2 iOS Configuration
1. **App Transport Security (`ios/Runner/Info.plist`)**:
   Allow connection to local development servers during testing:
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
       <key>NSAllowsLocalNetworking</key>
       <true/>
   </dict>
   ```

2. **Background App Refresh**:
   Enable background fetch capabilities in `ios/Runner/Info.plist`:
   ```xml
   <key>UIBackgroundModes</key>
   <array>
       <string>fetch</string>
       <string>processing</string>
   </array>
   ```

3. **Podfile Deployment Target**:
   Ensure `platform :ios, '13.0'` (already configured in `ios/Podfile`).

---

### 5.3 Backend Endpoint & Deployment
Because mobile devices cannot reach `localhost:3000` (which refers to the phone's loopback interface), the backend should be accessed via:
1. **Production (Recommended)**: Deploy the provided `backend/` to Vercel:
   * URL format: `https://streak-sync-[your-username].vercel.app`
   * Cost: $0.00/month.
2. **Local WiFi Testing**: Use the Mac's LAN IP:
   * URL format: `http://192.168.1.X:3000` (configurable directly in the Cloud Sync UI under "Custom Server URL").

---

## 6. Execution Phases & Testing Matrix

### Phase M1: Android Permission & Network Setup
- Update `AndroidManifest.xml` with `INTERNET` and `ACCESS_NETWORK_STATE`.
- Compile debug APK (`flutter build apk --debug`).
- Verify installation on Android device / emulator.

### Phase M2: iOS Entitlements & Pods
- Verify CocoaPods pod installation (`cd ios && pod install`).
- Configure `NSAppTransportSecurity` and `UIBackgroundModes`.
- Verify build on iOS Simulator (`flutter run -d iPhone`).

### Phase M3: Free Cloud Backend Deployment (Vercel + Supabase)
- Deploy `backend/` to Vercel free tier.
- Execute `src/db/schema.sql` in Supabase.
- Point the default `serverUrl` in `auth_service.dart` to the production Vercel URL.

### Phase M4: Cross-Device Verification Matrix

| Test Case | Steps | Expected Result |
| :--- | :--- | :--- |
| **Cross-Device Completion** | 1. Check habit on Mac.<br>2. Open mobile app. | Habit shows completed on mobile within 2 seconds. |
| **Offline Habits Queue** | 1. Turn on Airplane Mode on mobile.<br>2. Complete 2 habits & create a todo.<br>3. Turn Airplane Mode off. | Mobile queue flushes mutations; Mac updates automatically. |
| **Simultaneous Edits** | 1. Edit habit color on Mac at 12:00:00.<br>2. Edit habit name on phone at 12:00:05.<br>3. Sync both. | LWW resolves to 12:00:05 edit; completions from both merged. |
| **Backup Import Sync** | 1. Import backup file on phone. | All imported habits immediately populate local store and sync to Mac. |

---

## 7. Success Criteria & KPIs
* **Data Parity**: 100% agreement between Mac desktop and mobile DB after synchronization.
* **Sync Latency**: Under 1.5 seconds on active 4G/5G/WiFi.
* **Cost**: $0.00/month hosting & database bills.
* **Battery & Data Impact**: Zero background battery drain when inactive (only lightweight pull on foreground resume and 5-min timer).
