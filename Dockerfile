# Stage 1: Build the Go application
FROM golang:1.21-alpine AS builder
WORKDIR /app
# Copy the source code FROM the current host directory TO the /app directory in the container
COPY . .
# Build the Go binary statically
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Stage 2: Create the final, minimal image
FROM alpine:latest
WORKDIR /root/
# Copy the built binary from the 'builder' stage
COPY --from=builder /app/main .
EXPOSE 28080
# Command to run the application
CMD ["./main"]