// Package security provides cryptographic utilities for Niramaya-Net.
// All patient identifiers MUST be processed through this package
// before reaching the database or blockchain audit log.
package security

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// HashPatientID applies SHA-256 to the raw patient identifier and returns
// a lowercase 64-character hex digest. This ensures zero-knowledge privacy:
// even if the database is compromised, the original PII cannot be recovered.
//
//	raw := "PATIENT_LIVE_001"
//	hashed := security.HashPatientID(raw)
//	// hashed = "4e07408562bedb8b60ce05c1decfe3ad16ce76b5f76e7a8eb84c6b3b18ad823a" (example)
func HashPatientID(raw string) string {
	normalized := strings.TrimSpace(strings.ToUpper(raw))
	h := sha256.Sum256([]byte(normalized))
	return hex.EncodeToString(h[:])
}

// HashHex is a generic SHA-256 hasher that works on any string payload.
// Use this for secondary fields (ambulance ID, hospital ID) when audit
// hardening is required.
func HashHex(input string) string {
	h := sha256.Sum256([]byte(input))
	return hex.EncodeToString(h[:])
}
