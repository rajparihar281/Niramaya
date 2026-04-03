# Niramaya App — Work Log

---

## [2026-04-04] SCHEMA MIGRATION — Dispatch Engine + Flutter Error Handling

### SYSTEM_STATE
- Backend: `handleDispatch` now targets `public.drivers` (unified schema)
- Dispatch: Finds nearest hospital with a verified, on-duty driver
- Flutter: `DioException [bad response]` resolved — `validateStatus` + `no_drivers_available` handling
- Port: Go server confirmed on `0.0.0.0:10000`

### COMPLETED_TASKS
- [X] `niramaya-logistics/main.go` — Rewrote `handleDispatch`:
  - Query now joins `hospitals → drivers` on `d.hospital_id = h.id`
  - Filters: `d.is_on_duty = true`, `d.is_verified = true`, `d.is_active = true`, `h.is_active = true`
  - Removed dead joins to `departments`, `ambulances` (deleted tables)
  - No-driver case returns `200 {"status": "no_drivers_available"}` instead of `404`
  - Transaction now checks each `Exec`/`QueryRow` error and returns `500` on failure
  - Driver marked `is_on_duty = false` after assignment
- [X] `lib/data/api_client.dart` — Added `validateStatus: (s) => s != null && s < 600` to Dio `BaseOptions`. Prevents `DioException` on 4xx/5xx — callers inspect `response.statusCode` directly.
- [X] `lib/providers/dispatch_provider.dart` — `triggerDispatch` now:
  - Checks `response.statusCode >= 400` and surfaces readable error message
  - Handles `status == 'no_drivers_available'` with user-friendly message
  - Falls through to `DispatchModel.fromJson` only on clean 200 with `dispatch_id`

### FILES CHANGED
- `niramaya-backend/niramaya-logistics/main.go`
- `niramaya_app/lib/data/api_client.dart`
- `niramaya_app/lib/providers/dispatch_provider.dart`

---

### SYSTEM_STATE
- Hardware Mode: Intent-Aware (Samsung Side Key → `SosTriggerActivity` → `trigger_sos` extra → `MainActivity`)
- Automation: Zero-click dispatch on hardware launch (cold-start + hot-launch both handled)
- Safety: 3-second audio/haptic fuse with CANCEL button
- Double-tap Guard: 2-second debounce in `SosTriggerActivity.companion`

### COMPLETED_TASKS
- [X] Native Handshake: `SosTriggerActivity` now extends `AppCompatActivity`, passes `trigger_sos=true` extra to `MainActivity` and calls `finish()` immediately.
- [X] Double-tap Guard: `SystemClock.elapsedRealtime()` debounce (2s) prevents duplicate SOS from rapid side-key presses.
- [X] Cold-start Bridge: `MainActivity.configureFlutterEngine` exposes `checkInitialSos` via `MethodChannel("com.niramaya.app/sos")`. `main()` calls it before `runApp` and sets `initialRoute = '/sos-trigger'` if true.
- [X] Hot-launch Bridge: `MainActivity.onNewIntent` calls `MethodChannel.invokeMethod("triggerSos")` when app is already running; `_NiramayaAppState` listener pushes `/sos-trigger` via `navigatorKey`.
- [X] Manifest Fix: Removed duplicate `MAIN/LAUNCHER` intent filter from `SosTriggerActivity` (was causing double app icon). Fixed theme to `LaunchTheme`.
- [X] Gradle: Added explicit `androidx.appcompat:appcompat:1.7.0` dependency.

### ARCHITECTURE
```
Side Key press
  └─ SosTriggerActivity (AppCompatActivity)
       ├─ double-tap guard (2s debounce)
       └─ startActivity(MainActivity + trigger_sos=true) → finish()
            ├─ COLD START: checkInitialSos MethodChannel → initialRoute='/sos-trigger'
            └─ HOT LAUNCH: onNewIntent → invokeMethod('triggerSos') → Navigator.pushNamed('/sos-trigger')
                 └─ SosTriggerScreen: vibration + TTS + 3s fuse → dispatch
```

### BLOCKED_ISSUES
- Cold-boot latency: Flutter engine init (~1-2s) delays TTS on first launch. Mitigation: warm-up service (next sprint).

### FILES CHANGED
- `android/.../SosTriggerActivity.kt` — full rewrite: `AppCompatActivity`, intent extra, double-tap guard, `finish()`.
- `android/.../MainActivity.kt` — added `MethodChannel` for cold-start check and hot-launch `onNewIntent`.
- `android/app/build.gradle.kts` — added `appcompat:1.7.0` dependency.
- `android/.../AndroidManifest.xml` — removed duplicate launcher intent filter, fixed theme.
- `lib/main.dart` — cold-start `checkInitialSos` call, `navigatorKey`, hot-launch channel listener.

---

### SYSTEM_STATE
- Hardware Integration: Samsung Side Key → SosTriggerActivity (ACTIVE)
- Dispatch Mode: "Straight Pipe" Emergency (Zero-UI, auto `required_dept: emergency`)
- Network: ngrok Tunnel (HTTPS) — VERIFIED [200 OK]
- Safety Fuse: 3-second interstitial with haptic + TTS — ACTIVE

### COMPLETED_TASKS
- [X] Logic Pivot: Decoupled Manual App Launch (UI questions) from Hardware Trigger (auto-dispatch).
- [X] Safety Fuse: 3-second countdown interstitial on full-red screen prevents accidental dispatch.
- [X] Vibration: `[0, 500, 200, 500]` pulse pattern at max intensity on fuse start.
- [X] TTS: `flutter_tts` announces countdown on trigger; "Ambulance connected. Help is on the way." on 200 OK.
- [X] Cancel: Single large "CANCEL SOS" button aborts fuse, stops vibration/TTS, pops activity.
- [X] Atomic Dispatch: Auto-fetches GPS + ABHA identity, POSTs to `/v1/dispatch` with `required_dept: emergency`.
- [X] Post-Dispatch: Navigates to `DispatchTrackingScreen` on success; error state with retry on failure.

### FILES CHANGED
- `lib/screens/sos_trigger_screen.dart` — full rewrite with Safety Fuse state machine.
- `pubspec.yaml` — added `flutter_tts: ^4.0.2`, `vibration: ^2.0.0`.

### NEXT
- Run `flutter pub get` after this change.
- Test: Side Key → red screen appears → countdown → auto-dispatch → tracking screen.

---

### FULL AUDIT RESULT — NO CODE CHANGES REQUIRED

**Go router (`main.go`):**
```
r.Route("/v1", func(r chi.Router) {
    r.Post("/dispatch", handleDispatch)  // resolves → POST /v1/dispatch ✅
})
```
Listening on `0.0.0.0:10000` ✅

**Flutter (`constants.dart`):**
```
backendBaseUrl  = "https://jerold-nonimpressionistic-glynis.ngrok-free.dev"  // no trailing slash ✅
dispatchEndpoint = "/v1/dispatch"  // no double-slash ✅
```

**Previously applied fixes (sessions 1 & 2) that resolved the 404:**
- `lib/data/api_client.dart` — `ngrok-skip-browser-warning: true` header added (bypasses ngrok HTML interstitial).
- `android/app/src/main/res/xml/network_security_config.xml` — created; allowlists `ngrok-free.dev`, `ngrok-free.app`, `ngrok.io`.
- `android/app/src/main/AndroidManifest.xml` — wired `networkSecurityConfig`, `usesCleartextTraffic="false"`.

**Verification command:**
```powershell
Invoke-RestMethod -Uri "https://jerold-nonimpressionistic-glynis.ngrok-free.dev/v1/dispatch" -Method Post -Body '{"test":"ping"}' -ContentType "application/json"
```
Expected: Go logs show `200 | /v1/dispatch`

---

## [2026-03-30] PROJECT_WORKDONE.MD - VISION MVP V1.0

### SYSTEM_STATE
- **Vision Engine**: Gemini 1.5 Flash Vision API (Integrated & Active).
- **Network**: ngrok Tunnel (HTTPS) - ACTIVE.
- **Identity**: ABHA-linked Sovereign Profile (Stable).
- **Hardware Trigger**: Samsung Side Key Native Integration (Active).

### COMPLETED_TASKS
- [X] **Hardware SOS**: Implemented `SosTriggerActivity` and `/sos-trigger` route for instant lock-screen dispatch.
- [X] **Architecture Pivot**: Adopted the "Fast MVP" Vision strategy using `google_generative_ai` and `image_picker`.
- [X] **Logic Map**: Defined the flow from Image Capture -> Gemini ID -> Supabase Storage.
- [X] **UI Integration**: Added "Scan Meds" FAB and dynamically loading "Current Medications" list to the Sovereign Profile.
- [X] **Backend Compatibility**: Maintained the link between family members for potential medication alerts.

### BLOCKED_ISSUES
- **API Quotas**: Need to monitor Gemini Flash usage limits for the free tier.
- **Accuracy**: OCR might struggle with hand-written prescriptions; focusing on printed labels first.

### NEXT_SPRINT
1. **Gemini Prompt Engineering**: Refine the prompt to extract more discrete data (e.g., active compound, interactions).
2. **Scan Result UX Validation**: Ensure loading states aren't disrupted by app switching.
3. **Family Sync**: Allow family members to see Raj's scanned medications in real-time.

---

## Historical Log: Core Platform (Prior)

### ✅ Completed
- **Dependencies**: Configured `pubspec.yaml` with Riverpod, Supabase, Dio, Geolocator, flutter_map, crypto, generative_ai, image_picker.
- **Core Layer**: Applied `AppConstants`, `AppTheme`, and `ShaUtils`.
- **Data Layer**: Defined models `UserModel`, `PatientRecord`, `DispatchModel`, `MedicationModel`. Created `SupabaseClientHelper`, `VisionService`, and `ApiClient` for Go backend.
- **State Management (Riverpod)**:
    - Implemented `authProvider` (persistent login, ABHA-based auth).
    - Implemented `patientProvider` (fetch/save/cache with local encryption).
    - Implemented `dispatchProvider` (SOS trigger and status polling).
    - Implemented `medicationProvider` (fetch, save, Gemini integration).
- **UI Screens**:
    - `SplashScreen`, `LoginScreen`, `OtpScreen`, `HomeScreen`
    - `ProfileScreen` (Identity locks, Medicine FAB, Current Meds UI).
    - `ConsentScreen` (toggles for hospital access/gov sharing).
    - `DispatchTrackingScreen` (flutter_map, ambulance simulation).
- **Bug Fixes**:
    - Fixed Riverpod `StateNotifierListenerError` in `home_screen.dart`.
    - Fixed Class bounds mapping in `profile_screen.dart`.

### ⚠️ Known Issues
- `volume_button_listener` for raw power button detection is not yet implemented natively across all devices; relying on Samsung Side Key + Software SOS button.
- Dispatch tracking currently lacks real-time hospital coordinates in the backend response.

### 📁 Key Files
- `lib/core/constants.dart`: API/Supabase/Gemini configuration.
- `lib/providers/medication_provider.dart`: State & Scanner logic.
- `lib/services/vision_service.dart`: Google AI Gemini prompt parsing.
- `android/app/src/main/kotlin/.../SosTriggerActivity.kt`: Fast-launch SOS.
