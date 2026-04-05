# 📖 Niramaya-Net 3.0: ML Integration Guide (For UI & Backend Devs)

This document provides the exact data flow and API contracts required to connect the **Flutter/React Frontend** and the **Go Backend** to the **ML Microservice**.

---

## 🛠️ Engine 1: SOS, Triage & Queue

### 1.1 Implementation (React/Flutter)
When a patient hits "SOS," the system must perform a **Priority Calculation** before dispatching an ambulance.

```javascript
// Example: Requesting a Priority Score
const triageData = {
  symptoms: ["Severe Chest Pain", "Shortness of Breath"],
  pain_level: 9,
  age: 60,
  is_emergency: true
};

const response = await axios.post('http://localhost:8001/calculate-priority', triageData);
console.log(response.data.category); // Output: "CRITICAL"
```

### 1.2 Wait Time Display
Display the `predicted_wait_minutes` on the patient’s live queue tracker.
- **Endpoint**: `POST /predict`.
- **UI Tip**: If the prediction is `> 60 mins`, show an **"Urgent Delay"** badge.

---

## 🛰️ Engine 4: Epidemic Radar (Heatmap)

### 2.1 The "City-Wide Scan"
The Government Dashboard should call the radar every hour to update the heatmap.

```javascript
// Scan for Outbreaks
const radar = await axios.get('http://localhost:8001/predict-outbreak');
const outbreaks = radar.data.outbreaks;

// Loop through outbreaks for the map
outbreaks.forEach(alert => {
   if (alert.surge_alert_triggered) {
      // 1. Plot alert.location (lat, lng) on the map as a Red Zone
      // 2. Trigger a Banner for "CRITICAL Outbreak in Sector 2"
   }
});
```

---

## 🗺️ UI Mapping (Districts to Coordinates)
The ML Brain handles the mapping for you. The UI Developer just needs to use the `location` field from the JSON:

| District | Map Lat | Map Lng |
| :--- | :--- | :--- |
| **Sector 1** | `28.6139` | `77.2090` |
| **Sector 2** | `28.6200` | `77.2200` |
| **Sector 3** | `28.6300` | `77.2300` |

---

## ✅ Integration Checklist
1.  **CORS**: The ML service is configured to allow `*` origins. You can call it directly from localhost or through the Go Proxy.
2.  **Port**: Always use `http://localhost:8001`.
3.  **Surge Flag**: Look for `"surge_alert_triggered": true` inside the outbreak list. This is the **Primary Trigger** for your global alerts.

> [!CAUTION]
> **Safety**: Do NOT send the actual Patient Name or Aadhar ID to the ML service. Always send an anonymous `patient_hash` or just the clinical data.
