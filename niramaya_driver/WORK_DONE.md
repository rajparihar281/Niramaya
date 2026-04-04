# Niramaya Driver — Work Log

---

## [2026-04-04] SCHEMA ALIGNMENT — HospitalModel + Address Dropdown

### SYSTEM_STATE
- `hospitals` table extended with `address` (Text) and `is_active` (Boolean)
- Gwalior landmarks seeded: J.A. Hospital, Birla, Apollo
- Foreign keys for `drivers` and `ambulances` validated

### COMPLETED_TASKS
- [X] `lib/models/hospital_model.dart` — **created**. Fields: `id`, `name`, `address?`, `isActive`. `fromMap` factory uses `.toString()` for address and defaults `is_active` to `true` if null.
- [X] `registration_screen.dart` — Updated `_fetchHospitals` to select `id, name, address`. Switched `_hospitals` list type from `Map` to `HospitalModel`. Hospital dropdown now renders a two-line item: name (bold) + address (subtitle, ellipsized).

### FILES CHANGED
- `lib/models/hospital_model.dart` (new)
- `lib/screens/registration_screen.dart`

---

### SYSTEM_STATE
- Database Architecture: Unified `public.drivers` table (collapsed `staff_users` + `driver_details` + `ambulance_drivers`)
- Duty Toggle: `drivers.is_on_duty` via direct Supabase update
- Dashboard: Card-based layout (Status / Driver Info / Hospital)
- Region: Gwalior Deployment (Gajra Raja Medical College linked)

### COMPLETED_TASKS
- [X] `driver_profile_model.dart` — Replaced `fromStaffUser` + `mergeDriverDetails` with single `fromDrivers` factory. All fields now map directly from `public.drivers`.
- [X] `auth_provider.dart` — Replaced 2-table fetch (`staff_users` JOIN `driver_details`) with single `.from('drivers').select()` query.
- [X] `duty_provider.dart` — Updated table `ambulance_drivers` → `drivers`, field `is_online` → `is_on_duty`.
- [X] `registration_screen.dart` — Replaced 2-step insert (`staff_users` + `driver_details`) with single atomic insert into `drivers`. Fields: `staff_id`, `full_name`, `phone`, `email`, `license_number`, `years_experience`, `blood_group`, `hospital_id`, `role`, `is_verified`, `is_active`, `is_on_duty`.
- [X] `home_screen.dart` — Idle state refactored to Card-based `ListView`: Card A (ON/OFF DUTY status + radar), Card B (Full Name, Blood Group, License, Experience), Card C (Assigned Hospital). Removed duplicate status text below toggle pill.

### BLOCKED_ISSUES
- Admin Dashboard (React) must be updated to flip `drivers.is_verified` to unblock pending drivers.
- `hospitalNameProvider` still resolves by `hospital_id` — Card C shows ID until hospital name lookup is wired.

### FILES CHANGED
- `lib/models/driver_profile_model.dart`
- `lib/providers/auth_provider.dart`
- `lib/providers/duty_provider.dart`
- `lib/screens/registration_screen.dart`
- `lib/screens/home_screen.dart`

### NEXT_SPRINT
1. Live Duty Test: Confirm `drivers.is_on_duty` flips in Supabase Dashboard on toggle.
2. Wire `hospitalNameProvider` to display hospital name in Card C.
3. Gwalior Route: Test navigation from mock Gwalior driver location to Gwalior hospital.

---

### SYSTEM_STATE
- On-Duty Toggle: Direct Supabase `ambulance_drivers.is_online` update (no RPC dependency)
- Double-tap Guard: `isToggling` flag inside `DutyState` — provider-level, no race condition
- Map: Double-leg route (Driver→Patient blue, Patient→Hospital green) with Gwalior coordinates
- OTP: Auto-focus on first field via `initState` post-frame callback

### COMPLETED_TASKS
- [X] `duty_provider.dart` — Replaced `rpc('toggle_driver_duty')` with direct `.update({'is_online': newState}).eq('id', userId)`. Introduced `DutyState` with `isOnDuty` + `isToggling` fields. Loading guard prevents double-tap race condition at provider level.
- [X] `home_screen.dart` — Updated to read `dutyProvider.isOnDuty` and `dutyProvider.isToggling` from new `DutyState`. Removed manual `setState` for `_dutyToggling`.
- [X] `otp_screen.dart` — Added `initState` with `addPostFrameCallback` to auto-focus `_focusNodes[0]` on screen load.
- [X] `theme.dart` — Added `AppColors.emergencyBlue = Color(0xFF0D47A1)` for active dispatch state indicators.
- [X] `map_screen.dart` — Replaced hardcoded Mumbai coords with Gwalior fallbacks (`26.218, 78.182`). Patient/hospital locations now read from live `DispatchModel` fields. Double-leg polyline: Leg 1 (driver→patient, `emergencyBlue`), Leg 2 (patient→hospital, `success` green, dashed until pickup). Separate patient + hospital markers always visible.
- [X] `supabase/migrations/20260403000100_gwalior_driver_seed.sql` — Seeds 5 test drivers near Gwalior with PostGIS `geography(Point)` locations.

### FILES CHANGED
- `lib/providers/duty_provider.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/otp_screen.dart`
- `lib/screens/map_screen.dart`
- `lib/core/theme.dart`
- `niramaya-backend/supabase/migrations/20260403000100_gwalior_driver_seed.sql` (new)

### NEXT_SPRINT
- Wire `DispatchModel.patientLat/patientLng/hospitalLat/hospitalLng` from Supabase realtime payload
- Add OSRM/Valhalla routing API for actual road-following polylines instead of straight-line
- Implement daily stats (trips, km, hours) from `dispatches` table aggregation
