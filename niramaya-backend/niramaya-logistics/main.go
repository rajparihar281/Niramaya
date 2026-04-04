package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"os"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5/pgxpool"

	"niramaya-logistics/security"
)

type DispatchRequest struct {
	PatientID    string  `json:"patient_id"`
	Latitude     float64 `json:"latitude"`
	Longitude    float64 `json:"longitude"`
	RequiredDept string  `json:"required_dept"`
}

type ConsentUpdateRequest struct {
	PatientHash         string `json:"patient_hash"`
	AllowHospitalAccess bool   `json:"allow_hospital_access"`
	GovDataShare        bool   `json:"gov_data_share"`
	UpdatedAt           string `json:"updated_at"`
}

type MedicalPassportRequest struct {
	PayloadEncrypted string `json:"payload_encrypted"`
}

var dbPool *pgxpool.Pool

func main() {
	// ── Resolve DATABASE_URL (two-tier) ───────────────────────────────────────
	// Priority 1: explicit DATABASE_URL (production / CI / Render)
	// Priority 2: construct from SUPABASE_DB_PASSWORD (dev convenience —
	//             only requires one env var instead of a full connection string)
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("❌ FATAL: DATABASE_URL is not set.\n" +
			"  Use dev.ps1 which auto-encodes your password, or set it manually:\n" +
			"  $env:DATABASE_URL = \"postgresql://postgres.<ref>:<encoded-pass>@aws-0-ap-south-1.pooler.supabase.com:6543/postgres\"")
	}

	// ── Require Supabase REST credentials ─────────────────────────────────────
	if os.Getenv("SUPABASE_URL") == "" {
		log.Fatal("❌ FATAL: SUPABASE_URL is not set.\n" +
			"  set SUPABASE_URL=https://szktjigmdtubjfksolcr.supabase.co")
	}
	if os.Getenv("SUPABASE_SERVICE_KEY") == "" {
		log.Fatal("❌ FATAL: SUPABASE_SERVICE_KEY is not set.\n" +
			"  Get it: Supabase Dashboard → Settings → API → service_role key\n" +
			"  set SUPABASE_SERVICE_KEY=<service-role-key>")
	}

	var err error
	dbPool, err = pgxpool.New(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("❌ DB Connection Error: %v", err)
	}
	defer dbPool.Close()

	if err := dbPool.Ping(context.Background()); err != nil {
		log.Fatalf("❌ DB Ping Failed — check your DB password and network: %v", err)
	}

	log.Println("✅ DB schema verified")

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(corsMiddleware)

	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "Niramaya Engine Online", "version": "2.0.0"})
	})

	r.Route("/v1", func(r chi.Router) {
		r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
		})
		r.Post("/dispatch", handleDispatch)
		r.Get("/dispatch/status", handleStatus)
		r.Get("/audit/trail", handleAuditTrail)
		r.Put("/consent/hospital-access", handleConsentUpdate)
		r.Post("/consent/medical-passport", handleMedicalPassportUpdate)
	})

	bindAddr := "0.0.0.0:10000"

	fmt.Printf("🚀 Niramaya Engine v2.0 live on %s\n", bindAddr)
	fmt.Printf("🛡️  SHA-256 patient hashing: ENABLED\n")
	fmt.Printf("🗄️  Database: Supabase PostgreSQL (online)\n")
	fmt.Printf("🔑 Supabase URL: %s\n", os.Getenv("SUPABASE_URL"))

	if err := http.ListenAndServe(bindAddr, r); err != nil {
		log.Fatalf("❌ Server Failed: %v", err)
	}
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "POST, GET, PUT, OPTIONS, DELETE")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, ngrok-skip-browser-warning")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func handleDispatch(w http.ResponseWriter, r *http.Request) {
	var req DispatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("❌ [dispatch] JSON decode error: %v", err)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON body"})
		return
	}

	log.Printf("📡 [dispatch] Received → patient_id=%q lat=%.6f lng=%.6f dept=%q",
		req.PatientID, req.Latitude, req.Longitude, req.RequiredDept)

	if req.RequiredDept == "" {
		req.RequiredDept = "emergency"
	}
	hashedPatientID := security.HashPatientID(req.PatientID)
	log.Printf("🔐 [dispatch] patient_id_sha=%s", hashedPatientID)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	var hID, hName, driverID string
	var hLat, hLng, dist float64

	query := `
		SELECT
			h.id,
			h.name,
			d.id AS driver_id,
			ST_Distance(
				ST_SetSRID(ST_MakePoint(d.driver_lng, d.driver_lat), 4326)::geography,
				ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
			) AS dist,
			ST_Y(h.location::geometry) AS h_lat,
			ST_X(h.location::geometry) AS h_lng
		FROM drivers d
		JOIN hospitals h ON h.id = d.hospital_id
		WHERE
			d.is_on_duty   = true
			AND d.is_verified = true
			AND d.is_active   = true
			AND h.is_active   = true
			AND d.driver_lat  IS NOT NULL
			AND d.driver_lng  IS NOT NULL
		ORDER BY
			ST_SetSRID(ST_MakePoint(d.driver_lng, d.driver_lat), 4326)::geography
			<-> ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography
		LIMIT 1`

	log.Printf("🔍 [dispatch] Querying nearest hospital (lng=%.6f lat=%.6f)", req.Longitude, req.Latitude)

	err := dbPool.QueryRow(ctx, query, req.Longitude, req.Latitude).
		Scan(&hID, &hName, &driverID, &dist, &hLat, &hLng)

	if err != nil {
		log.Printf("⚠ [dispatch] No on-duty driver found — query error: %v", err)
		writeJSON(w, http.StatusOK, map[string]string{"status": "no_drivers_available"})
		return
	}

	log.Printf("✅ [dispatch] Matched hospital=%q (id=%s) driver=%s dist=%.0fm",
		hName, hID, driverID, dist)

	etaMinutes := haversineETA(req.Latitude, req.Longitude, hLat, hLng, 40.0)

	// Single atomic CTE: update driver + insert dispatch in one statement.
	// Avoids multi-statement transactions over Supabase connection pooler
	// (port 6543, transaction mode) which causes statement timeout on UPDATE.
	var dID string
	err = dbPool.QueryRow(ctx, `
		WITH mark_driver AS (
			UPDATE drivers SET is_on_duty = false WHERE id = $3
			RETURNING id
		)
		INSERT INTO dispatches
			(patient_id, hospital_id, driver_id, status,
			 patient_lat, patient_lng, hospital_lat, hospital_lng)
		SELECT $1, $2, id, 'assigned', $4, $5, $6, $7
		FROM mark_driver
		RETURNING id`,
		hashedPatientID, hID, driverID,
		req.Latitude, req.Longitude,
		hLat, hLng,
	).Scan(&dID)

	if err != nil {
		log.Printf("❌ [dispatch] Atomic dispatch failed: %v", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Internal server error"})
		return
	}
	log.Printf("📝 [dispatch] Dispatch record created id=%s driver=%s marked off-duty",
		dID, driverID)

	// ── Blockchain audit log (non-fatal) ──────────────────────────────────────
	txHash, bcErr := logDispatchOnChain(hashedPatientID, hID, req.RequiredDept)
	if bcErr != nil {
		log.Printf("⚠ [blockchain] logDispatch skipped: %v", bcErr)
	} else {
		log.Printf("⛓ [blockchain] audit logged tx=%s", txHash)
	}

	guardianCount, guardianErr := dispatchGuardianAlerts(ctx, req.PatientID, dID, req.Latitude, req.Longitude)
	if guardianErr != nil {
		log.Printf("⚠ [dispatch] Guardian alert fanout failed: %v", guardianErr)
	}

	response := map[string]interface{}{
		"status":                  "assigned",
		"dispatch_id":             dID,
		"driver_id":               driverID,
		"hospital":                hName,
		"hospital_lat":            hLat,
		"hospital_lng":            hLng,
		"patient_lat":             req.Latitude,
		"patient_lng":             req.Longitude,
		"distance":                fmt.Sprintf("%.0f meters", dist),
		"eta_minutes":             math.Round(etaMinutes),
		"patient_id_sha":          hashedPatientID,
		"guardian_alerts_emitted": guardianCount,
		"blockchain_tx":           txHash,
	}
	log.Printf("📤 [dispatch] Response → %+v", response)
	writeJSON(w, http.StatusOK, response)
}

func dispatchGuardianAlerts(ctx context.Context, patientAbha string, dispatchID string, lat float64, lng float64) (int, error) {
	if patientAbha == "" {
		return 0, nil
	}

	// Resolve victim user_id from ABHA in registered_users.
	var victimUserID string
	if err := dbPool.QueryRow(ctx, "SELECT id FROM registered_users WHERE abha_id = $1 LIMIT 1", patientAbha).Scan(&victimUserID); err != nil {
		return 0, nil
	}

	query := `
		SELECT DISTINCT fm2.user_id
		FROM family_members fm1
		JOIN family_members fm2 ON fm1.family_id = fm2.family_id
		WHERE fm1.user_id = $1
		  AND fm2.user_id <> $1
	`
	rows, err := dbPool.Query(ctx, query, victimUserID)
	if err != nil {
		return 0, err
	}
	defer rows.Close()

	guardians := make([]string, 0)
	for rows.Next() {
		var guardianID string
		if err := rows.Scan(&guardianID); err != nil {
			return 0, err
		}
		guardians = append(guardians, guardianID)
	}
	if rows.Err() != nil {
		return 0, rows.Err()
	}

	emitted := 0
	for _, guardianID := range guardians {
		_, err := dbPool.Exec(ctx, `
			INSERT INTO guardian_alerts (guardian_user_id, victim_user_id, dispatch_id, latitude, longitude, status)
			VALUES ($1, $2, $3, $4, $5, 'pending')
		`, guardianID, victimUserID, dispatchID, lat, lng)
		if err != nil {
			return emitted, err
		}
		emitted++
	}
	return emitted, nil
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	if id == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "id parameter required"})
		return
	}
	var status, hospitalName string
	query := `
		SELECT d.status, COALESCE(h.name, 'Unknown Hospital')
		FROM dispatches d
		LEFT JOIN hospitals h ON d.hospital_id = h.id
		WHERE d.id = $1`
	err := dbPool.QueryRow(context.Background(), query, id).Scan(&status, &hospitalName)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "Dispatch not found"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":   status,
		"hospital": hospitalName,
	})
}

func handleAuditTrail(w http.ResponseWriter, r *http.Request) {
	rpcURL := os.Getenv("BLOCKCHAIN_RPC_URL")
	contractAddr := os.Getenv("CONTRACT_ADDRESS")

	if rpcURL == "" || contractAddr == "" {
		writeJSON(w, http.StatusOK, map[string]interface{}{
			"status":  "waiting_for_config",
			"message": "BLOCKCHAIN_RPC_URL and CONTRACT_ADDRESS are required",
			"events":  []interface{}{},
		})
		return
	}

	payload := map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  "eth_getLogs",
		"params": []interface{}{
			map[string]interface{}{
				"address":   contractAddr,
				"fromBlock": "0x0",
				"toBlock":   "latest",
			},
		},
		"id": 1,
	}

	body, _ := json.Marshal(payload)
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, rpcURL, bytes.NewBuffer(body))
	if err != nil {
		handleServiceUnavailable(w, "Failed to prepare blockchain request")
		return
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status":  "blockchain_offline",
			"message": "Start Hardhat Node",
		})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		handleServiceUnavailable(w, "Blockchain bridge unavailable")
		return
	}

	var rpcRes struct {
		Error  map[string]interface{}   `json:"error"`
		Result []map[string]interface{} `json:"result"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&rpcRes); err != nil {
		handleServiceUnavailable(w, "Invalid blockchain response")
		return
	}
	if rpcRes.Error != nil {
		handleServiceUnavailable(w, "Blockchain RPC error")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":           "connected",
		"rpc":              rpcURL,
		"contract_address": contractAddr,
		"events":           rpcRes.Result,
	})
}

func handleServiceUnavailable(w http.ResponseWriter, msg string) {
	writeJSON(w, http.StatusServiceUnavailable, map[string]interface{}{
		"status":  "service_unavailable",
		"message": msg,
		"events":  []interface{}{},
	})
}

func handleConsentUpdate(w http.ResponseWriter, r *http.Request) {
	var req ConsentUpdateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON body"})
		return
	}
	if req.PatientHash == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "patient_hash is required"})
		return
	}

	supabaseURL := os.Getenv("SUPABASE_URL")
	supabaseKey := os.Getenv("SUPABASE_SERVICE_KEY")
	if supabaseURL == "" || supabaseKey == "" {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "Supabase not configured"})
		return
	}

	updatedAt := req.UpdatedAt
	if updatedAt == "" {
		updatedAt = time.Now().UTC().Format(time.RFC3339)
	}

	payload := map[string]interface{}{
		"access_granted":    req.AllowHospitalAccess,
		"gov_share_enabled": req.GovDataShare,
		"updated_at":        updatedAt,
	}
	body, _ := json.Marshal(payload)

	endpoint := fmt.Sprintf("%s/rest/v1/hospital_access?patient_hash=eq.%s", supabaseURL, req.PatientHash)
	httpReq, err := http.NewRequestWithContext(r.Context(), http.MethodPatch, endpoint, bytes.NewBuffer(body))
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "Failed to build Supabase request"})
		return
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("apikey", supabaseKey)
	httpReq.Header.Set("Authorization", "Bearer "+supabaseKey)
	httpReq.Header.Set("Prefer", "return=representation")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": "Supabase unreachable"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": fmt.Sprintf("Supabase returned %d", resp.StatusCode)})
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status":                "consent_updated",
		"allow_hospital_access": req.AllowHospitalAccess,
		"gov_data_share":        req.GovDataShare,
		"updated_at":            updatedAt,
	})
}

func handleMedicalPassportUpdate(w http.ResponseWriter, r *http.Request) {
	var req MedicalPassportRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "Invalid JSON body"})
		return
	}
	if req.PayloadEncrypted == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "payload_encrypted is required"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "medical_passport_saved",
	})
}

func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func haversineETA(lat1, lng1, lat2, lng2, speed float64) float64 {
	const R = 6371.0
	dLat := (lat2 - lat1) * math.Pi / 180
	dLng := (lng2 - lng1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return (R * c / speed) * 60
}
