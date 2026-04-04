package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
)

// Structs
type DispatchRequest struct {
	PatientLat float64 `json:"patient_lat"`
	PatientLng float64 `json:"patient_lng"`
	PatientID  string  `json:"patient_id"`
	AbhaID     string  `json:"abha_id,omitempty"`
}

type DispatchStatusUpdate struct {
	Status string `json:"status"`
}

type DispatchResponse struct {
	DispatchID   string  `json:"dispatch_id"`
	DriverID     string  `json:"driver_id"`
	DriverName   string  `json:"driver_name"`
	HospitalName string  `json:"hospital_name"`
	HospitalLat  float64 `json:"hospital_lat"`
	HospitalLng  float64 `json:"hospital_lng"`
	ETASeconds   int     `json:"eta_seconds"`
}

// Global DB instance assumption (inject via your preferred method)
var db *sql.DB

func RegisterDispatchRoutes(r chi.Router) {
	r.Post("/dispatch/request", handleDispatchRequest)
	r.Patch("/dispatch/{id}/status", handleDispatchStatusUpdate)
	r.Get("/hospital/{id}/beds", handleGetHospitalBeds)
}

// 1. POST /dispatch/request
func handleDispatchRequest(w http.ResponseWriter, r *http.Request) {
	var req DispatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// 1. Nearest Driver Query using PostGIS <-> operator
	var driverID, driverName string
	driverQuery := `
		SELECT id, name
		FROM drivers
		WHERE is_on_duty = true
		ORDER BY last_location <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)
		LIMIT 1;`
	
	err := db.QueryRowContext(r.Context(), driverQuery, req.PatientLng, req.PatientLat).Scan(&driverID, &driverName)
	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "No drivers available", http.StatusServiceUnavailable)
			return
		}
		http.Error(w, "Driver lookup failed", http.StatusInternalServerError)
		return
	}

	// 2. Nearest Hospital Query
	var hospID, hospName string
	var hospLat, hospLng float64
	hospQuery := `
		SELECT id, name, ST_Y(location::geometry), ST_X(location::geometry)
		FROM hospitals
		WHERE emergency_beds_available > 0
		ORDER BY location <-> ST_SetSRID(ST_MakePoint($1, $2), 4326)
		LIMIT 1;`
	
	err = db.QueryRowContext(r.Context(), hospQuery, req.PatientLng, req.PatientLat).Scan(&hospID, &hospName, &hospLat, &hospLng)
	if err != nil && err != sql.ErrNoRows {
		http.Error(w, "Hospital lookup failed", http.StatusInternalServerError)
		return
	}

	// 3. Insert Dispatch
	dispatchID := uuid.New().String()
	insertQuery := `
		INSERT INTO dispatches (
			id, patient_id, driver_id, status,
			patient_lat, patient_lng,
			hospital_lat, hospital_lng,
			hospital_name, hospital_id,
			created_at, updated_at
		) VALUES (
			$1, $2, $3, 'assigned',
			$4, $5, $6, $7, $8, $9, NOW(), NOW()
		)`
	
	_, err = db.ExecContext(r.Context(), insertQuery,
		dispatchID, req.PatientID, driverID,
		req.PatientLat, req.PatientLng,
		hospLat, hospLng, hospName, hospID,
	)
	if err != nil {
		http.Error(w, "Failed to create dispatch", http.StatusInternalServerError)
		return
	}

	// 4. Supabase Realtime Broadcast (Requires Supabase Go Client or direct HTTP call to PostgREST/Realtime with Service Role Key)
	// broadcastToDriverChannel(driverID, dispatchID) -> implemented via external trigger

	resp := DispatchResponse{
		DispatchID:   dispatchID,
		DriverID:     driverID,
		DriverName:   driverName,
		HospitalName: hospName,
		HospitalLat:  hospLat,
		HospitalLng:  hospLng,
		ETASeconds:   300, // Would typically be evaluated via OSRM here if backend needs strict ETA calculation, else frontend does it
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// 2. PATCH /dispatch/:id/status
func handleDispatchStatusUpdate(w http.ResponseWriter, r *http.Request) {
	dispatchID := chi.URLParam(r, "id")
	
	var update DispatchStatusUpdate
	if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
		http.Error(w, "Invalid request payload", http.StatusBadRequest)
		return
	}

	// Enforce strict state machine (Validation omitted for brevity, assumed safe inputs)
	query := `
		UPDATE dispatches
		SET status = $1, updated_at = NOW()
		WHERE id = $2
	`
	_, err := db.ExecContext(r.Context(), query, update.Status, dispatchID)
	if err != nil {
		http.Error(w, "Failed to update dispatch status", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

// 3. GET /hospital/:id/beds
func handleGetHospitalBeds(w http.ResponseWriter, r *http.Request) {
	hospID := chi.URLParam(r, "id")
	var em, icu int
	
	err := db.QueryRowContext(r.Context(), "SELECT emergency_beds_available, icu_beds_available FROM hospitals WHERE id = $1", hospID).Scan(&em, &icu)
	
	if err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "Hospital not found", http.StatusNotFound)
			return
		}
		http.Error(w, "Database error", http.StatusInternalServerError)
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]int{
		"emergency_beds": em,
		"icu_beds": icu,
	})
}
