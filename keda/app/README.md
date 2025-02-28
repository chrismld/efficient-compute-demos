# Monte Carlo PI Simulation

## Prepare the app

```
go mod init monte-carlo-api
go get github.com/prometheus/client_golang/prometheus
go get github.com/prometheus/client_golang/prometheus/promhttp
go mod tidy
```

## Run it locally

```
go run main.go
```

## Docker build

```
docker build -t monte-carlo-api:latest .
```

## Test it

```
curl "http://localhost:8080/simulate?iterations=100000"
```