# Build Stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy go module files (wildcards support building from repo root or backend folder)
COPY go.mod* go.sum* backend/go.mod* backend/go.sum* ./
RUN go mod download

# Copy source code
COPY . .

# If building from repo root, copy backend contents to current dir
RUN if [ -d "backend" ]; then cp -r backend/* . && rm -rf backend; fi

# Build binary
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Final Run Stage
FROM alpine:latest

WORKDIR /app

# Copy binary and configuration from builder
COPY --from=builder /app/main .
COPY --from=builder /app/swagger.yaml ./swagger.yaml

EXPOSE 8080

CMD ["./main"]
