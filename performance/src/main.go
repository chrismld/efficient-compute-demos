package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"log"
	"net/http"
	"runtime"
	"time"

	"github.com/pierrec/lz4/v4"
)

type LogEntry struct {
	Timestamp string                 `json:"timestamp"`
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	Metadata  map[string]interface{} `json:"metadata,omitempty"`
}

type LogBatchRequest struct {
	Logs []LogEntry `json:"logs"`
}

type LogBatchResponse struct {
	Received       int    `json:"received"`
	Stored         string `json:"stored"`
	OriginalBytes  int    `json:"original_bytes"`
	StoredBytes    int    `json:"stored_bytes"`
	CompressionPct int    `json:"compression_pct"`
	ProcessingTime string `json:"processing_time"`
}

func handleLogBatch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req LogBatchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	if len(req.Logs) == 0 {
		http.Error(w, "No logs provided", http.StatusBadRequest)
		return
	}

	start := time.Now()

	// Serialize logs to JSON
	logsJSON, err := json.Marshal(req.Logs)
	if err != nil {
		http.Error(w, "Failed to process logs", http.StatusInternalServerError)
		return
	}

	// Compress the log batch for storage
	compressedData, err := compressLogs(logsJSON)
	if err != nil {
		http.Error(w, "Failed to compress logs", http.StatusInternalServerError)
		return
	}

	duration := time.Since(start)

	// Encode compressed data for storage/transmission
	encodedData := base64.StdEncoding.EncodeToString(compressedData)

	compressionPct := 100 - (len(compressedData) * 100 / len(logsJSON))

	response := LogBatchResponse{
		Received:       len(req.Logs),
		Stored:         encodedData[:min(50, len(encodedData))] + "...",
		OriginalBytes:  len(logsJSON),
		StoredBytes:    len(compressedData),
		CompressionPct: compressionPct,
		ProcessingTime: duration.String(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func compressLogs(data []byte) ([]byte, error) {
	// Use block compression API (no streaming overhead)
	maxCompressedSize := lz4.CompressBlockBound(len(data))
	compressed := make([]byte, maxCompressedSize)
	
	var n int
	var err error
	
	// Moderate iterations - enough to show CPU differences without overwhelming
	iterations := 8
	for i := 0; i < iterations; i++ {
		n, err = lz4.CompressBlock(data, compressed, nil)
		if err != nil {
			return nil, err
		}
	}
	
	// Return only the actual compressed bytes from the last iteration
	return compressed[:n], nil
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	health := map[string]interface{}{
		"status":       "healthy",
		"architecture": runtime.GOARCH,
		"go_version":   runtime.Version(),
		"lz4_version":  "v4.0.0",
		"num_cpu":      runtime.NumCPU(),
		"timestamp":    time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(health)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func main() {
	// Set GOMAXPROCS to use all available CPUs
	runtime.GOMAXPROCS(runtime.NumCPU())
	
	http.HandleFunc("/api/logs/batch", handleLogBatch)
	http.HandleFunc("/health", handleHealth)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		info := map[string]interface{}{
			"service": "Log Aggregation API",
			"version": "1.0.0",
			"lz4_version": "v4.0.0",
			"architecture": runtime.GOARCH,
			"endpoints": map[string]string{
				"POST /api/logs/batch": "Submit batch of log entries",
				"GET /health":          "Health check",
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(info)
	})

	log.Printf("Log Aggregation Service starting on :8080 (arch=%s, cpus=%d)", runtime.GOARCH, runtime.NumCPU())
	log.Fatal(http.ListenAndServe(":8080", nil))
}