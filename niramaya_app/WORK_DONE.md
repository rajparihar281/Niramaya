# Niramaya App — Work Log

---

## [2026-04-04] NETWORK HANDSHAKE REPAIR — Global Dio Interceptor

### SYSTEM_STATE
- Network Layer: Centralized Dio interceptor handles all connection failures
- NativeSocket.lookup: No longer pauses debugger — resolved as synthetic 503
- Dispatch UI: Shows "Retry Connection" state on engine-offline instead of crashing

### COMPLETED_TASKS
- [X] `api_client.dart` — `onError` interceptor now catches `connectionError`, `connectionTimeout`, `receiveTimeout`, `sendTimeout`, and `SocketException`. Resolves them as `Response(statusCode: 503, data: {error, hint})` via `handler.resolve()`. Debugger no longer pauses on `_NativeSocket.lookup`.
- [X] `dispatch_provider.dart` — Added explicit `503` check before the generic `>=400` branch. Shows `"Connection Error: Niramaya Engine is currently offline."` with ngrok hint. Simplified `catch` block — network errors no longer reach it. Removed unused `dart:io` and `dio` imports.
- [X] `sos_trigger_screen.dart` — On `503`/network error: reverts to `'fuse'` phase with fresh countdown + SnackBar. On logic errors: shows `'error'` phase with RETRY button.

### ERROR FLOW (after fix)
```
ngrok tunnel down
  └─ Dio fires DioExceptionType.connectionError
       └─ Interceptor.onError catches it
            └─ handler.resolve(Response(503, {error, hint}))
                 └─ dispatch_provider sees statusCode==503
                      └─ state.error = "Connection Error..."
                           └─ SOS screen reverts to fuse phase + SnackBar
```

### FILES CHANGED
- `lib/data/api_client.dart`
- `lib/providers/dispatch_provider.dart`

---

### SYSTEM_STATE
- Dispatch Row: Stores full coordinate snapshot — `patient_lat/lng` + `hospital_lat/lng`
- Map Integrity: Both apps read from the same `dispatches` columns via Realtime
- Namespace: `hospitalNameProvider` collision resolved

### COMPLETED_TASKS
- [X] `main.go` — `handleDispatch` INSERT now writes all 4 coords atomically. Response JSON includes `hospital_lat/lng` + `patient_lat/lng`. `autoMigrate` adds all 4 columns via `ADD COLUMN IF NOT EXISTS`.
- [X] `niramaya_app/lib/data/models/dispatch_model.dart` — `fromJson` maps `hospital_lat`, `hospital_lng`, `patient_lat`, `patient_lng` from response.
- [X] `niramaya_driver/lib/screens/map_screen.dart` — `patientLocation` and `hospitalLocation` derived from `ref.watch(dispatchProvider)` in `build()`. Auto-pans to `patientLocation` on new dispatch. Removed stale `ref.read` getter methods.
- [X] `niramaya_driver/lib/providers/dispatch_provider.dart` — Realtime filter uses `driver_id`. `_enrichDispatch` reads coords directly from the row (no RPC needed). `completeDispatch` uses `drivers` table.
- [X] `niramaya_driver/lib/screens/home_screen.dart` — Added `hide hospitalNameProvider` to `dispatch_provider` import to resolve ambiguous import collision.

### COORDINATE FLOW
```
SOS Request (lat/lng) → Go Backend
  └─ PostGIS query → hospital_lat/lng
  └─ INSERT dispatches (patient_lat, patient_lng, hospital_lat, hospital_lng)
  └─ HTTP response includes all 4 coords
       ├─ User App: DispatchModel.fromJson → map markers placed immediately
       └─ Driver App: Supabase Realtime row → map markers placed immediately
```

### FILES CHANGED
- `niramaya-backend/niramaya-logistics/main.go`
- `niramaya_app/lib/data/models/dispatch_model.dart`
- `niramaya_driver/lib/screens/map_screen.dart`
- `niramaya_driver/lib/providers/dispatch_provider.dart`
- `niramaya_driver/lib/screens/home_screen.dart`

---

### SYSTEM_STATE
- Driver Alerts: Supabase Realtime subscribed by `driver_id` (unified schema)
- Map Coordinates: Fetched from DB via hospital JOIN — no more mock coords
- Location Broadcast: `drivers.last_location` updated every 5s when on duty
- Dispatch Complete: Marks driver `is_on_duty=true` after trip ends

### COMPLETED_TASKS
- [X] `dispatch_provider.dart` (driver) — Realtime filter changed from `ambulance_id` → `driver_id`. `_enrichDispatch` does a JOIN to `hospitals` to fetch `ST_Y/ST_X` coords and hospital name, merging into `DispatchModel`. `completeDispatch` fixed: removed reference to deleted `staff_driver_details`, now updates `drivers.is_on_duty=true` after trip.
- [X] `location_service.dart` — Added `startLocationBroadcast(driverId)`: `Timer.periodic(5s)` writes `POINT(lng lat)` to `drivers.last_location`. Added `stopLocationBroadcast()`.
- [X] `home_screen.dart` — `_initDriverState` now calls `initRealtimeSubscription(profile.id)` (driver UUID, not ambulanceId). Starts broadcast if already on duty. `_toggleDuty` starts/stops broadcast on state change.

### SYMMETRIC COORDINATE FLOW
```
User App writes GPS → dispatches.patient_lat / patient_lng
Driver App reads   ← dispatches.patient_lat / patient_lng  (patient marker)
Driver App writes  → drivers.last_location (POINT every 5s)
User App reads     ← drivers.last_location  (ambulance marker)
Hospital coords    ← hospitals.location (ST_Y/ST_X via JOIN)
```

### FILES CHANGED
- `niramaya_driver/lib/providers/dispatch_provider.dart`
- `niramaya_driver/lib/services/location_service.dart`
- `niramaya_driver/lib/screens/home_screen.dart`

---

### SYSTEM_STATE
- Hospital Nodes: 7 Gwalior landmarks cycling in dispatch UI
- Dispatch UX: Animated hospital scanner replaces static spinner
- Fallback: `no_drivers_available` → "Broadcast to Private Ambulances" button

### COMPLETED_TASKS
- [X] `dispatch_provider.dart` — Added `scanningHospital` + `noDriversAvailable` to `DispatchState`. `DispatchNotifier` starts a `Timer.periodic(1.2s)` cycling through 7 Gwalior hospital names during the backend call, updating `scanningHospital` state each tick. Timer cancelled on response.
- [X] `sos_trigger_screen.dart` — New `_DispatchingView` widget: `AnimatedSwitcher` with fade+slide transition shows `"Checking availability at <hospital>"` cycling live. New `_NoDriverView`: warning icon, explanation text, `BROADCAST TO PRIVATE AMBULANCES` button (retries dispatch), Cancel button. Phase state machine extended: `fuse | dispatching | success | no_drivers | error`.

### FILES CHANGED
- `lib/providers/dispatch_provider.dart`
- `lib/screens/sos_trigger_screen.dart`

---

### SYSTEM_STATE
- `handleDispatch`: Fully aligned to unified `drivers` table — no references to deleted tables
- `handleStatus`: Fixed — removed JOIN on deleted `ambulances` table
- `autoMigrate`: Adds `dispatches.driver_id` column idempotently on startup
- Port: `0.0.0.0:10000` — confirmed

### COMPLETED_TASKS
- [X] `handleDispatch` — JOIN `hospitals h` → `drivers d ON d.hospital_id = h.id`. Filters: `is_on_duty=true`, `is_verified=true`, `is_active=true` (both tables). Returns `200 {status: no_drivers_available}` when no match. Marks assigned driver `is_on_duty=false`. Inserts dispatch with `driver_id`.
- [X] `handleStatus` — Removed dead JOIN on `ambulances` (deleted). Now queries `dispatches LEFT JOIN hospitals` for `status` + `hospital name`.
- [X] `autoMigrate` — Added `ALTER TABLE dispatches ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES drivers(id)` so dispatch records are fully traceable to the assigned driver.

### DELETED TABLE REFERENCES REMOVED
| Old reference | Replaced with |
|---|---|
| `JOIN ambulances a ON d.ambulance_id = a.id` | `LEFT JOIN hospitals h ON d.hospital_id = h.id` |
| `JOIN departments d ON h.id = d.hospital_id` | removed (no departments table) |
| `a.status = 'available'` | `d.is_on_duty = true` |
| `UPDATE ambulances SET status = 'busy'` | `UPDATE drivers SET is_on_duty = false` |

### FILES CHANGED
- `niramaya-backend/niramaya-logistics/main.go`

---

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
