package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	latencyHistogram = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "monte_carlo_latency_seconds",
			Help:    "Latency of Monte Carlo simulations in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"status"},
	)
)

func init() {
	prometheus.MustRegister(latencyHistogram)
}

type MonteCarloResponse struct {
	PiEstimate float64 `json:"pi_estimate"`
	Iterations int     `json:"iterations"`
}

func monteCarloPi(iterations int) float64 {
	var insideCircle int
	rand.Seed(time.Now().UnixNano())

	for i := 0; i < iterations; i++ {
		x, y := rand.Float64(), rand.Float64()
		if x*x+y*y <= 1 {
			insideCircle++
		}
	}

	return 4.0 * float64(insideCircle) / float64(iterations)
}

func handleMonteCarlo(w http.ResponseWriter, r *http.Request) {
	startTime := time.Now()

	if r.Method != http.MethodGet {
		http.Error(w, "Only GET method is allowed", http.StatusMethodNotAllowed)
		recordLatency(startTime, http.StatusMethodNotAllowed)
		return
	}

	iterationsStr := r.URL.Query().Get("iterations")
	iterations, err := strconv.Atoi(iterationsStr)
	if err != nil || iterations <= 0 {
		http.Error(w, "Invalid iterations parameter", http.StatusBadRequest)
		recordLatency(startTime, http.StatusBadRequest)
		return
	}

	piEstimate := monteCarloPi(iterations)
	resp := MonteCarloResponse{PiEstimate: piEstimate, Iterations: iterations}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		recordLatency(startTime, http.StatusInternalServerError)
		return
	}

	recordLatency(startTime, http.StatusOK)
}

func recordLatency(startTime time.Time, status int) {
	duration := time.Since(startTime).Seconds()
	statusLabel := fmt.Sprintf("%d", status)
	latencyHistogram.WithLabelValues(statusLabel).Observe(duration)
}

func main() {
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/simulate", handleMonteCarlo)

	fmt.Println("Server running on port 8080...")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
	}
}