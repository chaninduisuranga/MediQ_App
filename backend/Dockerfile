# Build Stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

# Copy go module files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

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
