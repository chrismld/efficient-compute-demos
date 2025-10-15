# Log Aggregation Service

A lightweight HTTP service for collecting and storing application logs with automatic compression. Built with Go and LZ4 compression to efficiently handle high-volume log ingestion.

## Overview

This service provides a simple API for applications to submit batches of log entries. Logs are automatically compressed using LZ4 before storage, reducing storage costs and improving transmission efficiency.

## Features

- **Batch Log Ingestion**: Accept multiple log entries in a single request
- **Automatic Compression**: LZ4 compression reduces storage footprint by 60-80%
- **Multi-Architecture**: Runs on both ARM64 and x86-64 architectures
- **Health Monitoring**: Built-in health check endpoint
- **Kubernetes Ready**: Production-ready manifests included

## Quick Start

### Build Container Image

```bash
docker build \
  -t your-registry/log-aggregator:latest \
  --push .
```

### Deploy to Kubernetes

```bash
# Update the image in the deployment manifest
kubectl apply -f k8s-deployment.yaml

# Verify deployment
kubectl get pods -l app=log-aggregator
kubectl get svc log-aggregator-x86
```

### Test the Service

```bash
# Port forward to access locally
kubectl port-forward svc/log-aggregator-x86 8080:8080

# Submit a batch of logs
curl -X POST http://localhost:8080/api/logs/batch \
  -H "Content-Type: application/json" \
  -d '{
    "logs": [
      {
        "timestamp": "2025-10-14T10:30:00Z",
        "level": "info",
        "message": "Application started successfully",
        "metadata": {
          "service": "api-gateway",
          "version": "1.2.3"
        }
      },
      {
        "timestamp": "2025-10-14T10:30:05Z",
        "level": "error",
        "message": "Database connection timeout",
        "metadata": {
          "service": "api-gateway",
          "retry_count": 3
        }
      }
    ]
  }'

# Check health
curl http://localhost:8080/health
```

## API Reference

### POST /api/logs/batch

Submit a batch of log entries for storage.

**Request Body:**
```json
{
  "logs": [
    {
      "timestamp": "2025-10-14T10:30:00Z",
      "level": "info|warn|error|debug",
      "message": "Log message text",
      "metadata": {
        "key": "value"
      }
    }
  ]
}
```

**Response:**
```json
{
  "received": 2,
  "stored": "H4sIAAAAAAAA/6pWKkktLlGyUlAqS8wpTtVRKi1OLUpV...",
  "original_bytes": 245,
  "stored_bytes": 98,
  "compression_pct": 60,
  "processing_time": "1.234ms"
}
```

### GET /health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "architecture": "arm64",
  "go_version": "go1.21.0",
  "timestamp": "2025-10-14T10:30:00Z"
}
```

## Deployment Configuration

The service includes two deployment options:

1. **ARM-Specific** (`log-aggregator-arm`): Targets ARM64 nodes explicitly
2. **x86-Specific** (`log-aggregator-x86`): Targets AMD64 nodes explicitly

### Resource Limits

- **CPU**: 1500m request
- **Memory**: 3512Mi request, 3512Mi limit

### Ports

- **8080**: HTTP API

## Building Locally

```bash
# Install dependencies
go mod download

# Build
go build -o log-aggregator .

# Run
./log-aggregator
```

## Environment Variables

- `GOMAXPROCS`: Number of CPU cores to use (default: all available)

## Compression Details

The service uses LZ4 compression which provides:
- Fast compression speed (500+ MB/s)
- Fast decompression speed (2000+ MB/s)
- Typical compression ratio: 60-80% for text logs
- Low CPU overhead

Compressed logs are base64-encoded for safe transmission and storage.

## Production Considerations

- Configure persistent storage for compressed logs
- Set up log rotation policies
- Monitor compression ratios to detect anomalies
- Use LoadBalancer or Ingress for external access
- Enable TLS for production deployments
- Implement authentication/authorization as needed

## Load Testing

The service includes k6 load tests to validate performance under high traffic. The k6 operator must be installed in your cluster.

### Run Load Test

```bash
# Apply the k6 test manifest
kubectl apply -f ../manifests/k6-test.yaml

# Monitor the log-aggregator CPU usage
kubectl top pod -l app=log-aggregator --watch

# View k6 test logs (12 pods will be created)
kubectl logs -l k6_cr=log-aggregator-x86 -f --max-log-requests 14
kubectl logs -l k6_cr=log-aggregator-arm -f --max-log-requests 14
```

### Re-run Load Test

```bash
# Delete the existing test run
kubectl delete testrun --all

# Wait for pods to terminate
kubectl get pods -l k6_cr=log-aggregator-load-test

# Apply again
kubectl apply -f ../manifests/k6-test.yaml
```

### Load Test Configuration

The test runs with:
- **12 parallel k6 pods** (1,020 total virtual users)
- **60 VUs per pod** for 5 minutes
- **1,000 logs per batch** with large messages
- Target: ~90% CPU utilization on the log-aggregator pod

To adjust load intensity, modify the `vus` value in the ConfigMap (85 = ~90% CPU, 100 = ~100%+ CPU).

### Running aperf

```bash
bash ./eks-aperf.sh \
  --aperf_image="christianhxc/aperf:latest" \
  --node="$(kubectl get pod -l app=log-aggregator-x86 -o jsonpath='{.items[0].spec.nodeName}')" \
  --aperf_options="-p 90 --profile" \
  --report-name="x86"
```

```bash
bash ./eks-aperf.sh \
  --aperf_image="christianhxc/aperf:latest" \
  --node="$(kubectl get pod -l app=log-aggregator-arm -o jsonpath='{.items[0].spec.nodeName}')" \
  --aperf_options="-p 90 --profile" \
  --report-name="arm"
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod -l app=log-aggregator
kubectl logs -l app=log-aggregator
```

### Service not accessible
```bash
# Check service endpoints
kubectl get endpoints log-aggregator-service

# Use NodePort if LoadBalancer unavailable
kubectl patch svc log-aggregator-service -p '{"spec":{"type":"NodePort"}}'
```