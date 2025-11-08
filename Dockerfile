# syntax=docker/dockerfile:1.4
# Enable BuildKit for parallel builds and advanced features

# Base image with Go and build tools
FROM golang:1.24-bullseye AS build-base

# Install system dependencies for IBM MQ client
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    wget \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set up build environment
ENV CGO_ENABLED=1
ENV GOOS=linux
ENV GOARCH=amd64

# Create app directory
WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies (this layer will be cached)
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# IBM MQ Client stage
FROM build-base as mq-client

# Download and install IBM MQ client libraries
# Using a more reliable download approach with error handling
ENV MQ_VERSION=9.3.4.1
ENV MQ_BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqdev/redist"

RUN --mount=type=cache,target=/tmp/mqclient \
    cd /tmp/mqclient && \
    # Try primary URL, fallback to alternative if needed
    (wget -q "${MQ_BASE_URL}/${MQ_VERSION}-IBM-MQC-Redist-LinuxX64.tar.gz" || \
    wget -q "https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqdev/redist/9.3.4.1-IBM-MQC-Redist-LinuxX64.tar.gz") && \
    tar -xzf "*IBM-MQC-Redist-LinuxX64.tar.gz" && \
    cd mqm && \
    # Install MQ client libraries
    mkdir -p /opt/mqm && \
    cp -r inc /opt/mqm/ && \
    cp -r lib64 /opt/mqm/ && \
    # Set up library path
    echo "/opt/mqm/lib64" > /etc/ld.so.conf.d/mqm.conf && \
    ldconfig

# Build stage
FROM mq-client as builder

# Set MQ environment variables for CGO
ENV CGO_CFLAGS="-I/opt/mqm/inc"
ENV CGO_LDFLAGS="-L/opt/mqm/lib64 -lmqm"

# Copy source code
COPY . .

# Build with caching for dependencies and parallel compilation
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -ldflags="-w -s" -o /app/bin/collector ./cmd/collector

# Test stage (runs in parallel with build)
FROM builder as test
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go test -v ./pkg/config ./pkg/pcf

# Runtime base
FROM debian:bullseye-slim as runtime-base

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy MQ client libraries from build stage
COPY --from=mq-client /opt/mqm/lib64 /opt/mqm/lib64
COPY --from=mq-client /etc/ld.so.conf.d/mqm.conf /etc/ld.so.conf.d/mqm.conf

# Update library cache
RUN ldconfig

# Create non-root user for security
RUN groupadd -r ibmmq && useradd -r -g ibmmq -s /bin/false ibmmq

# Final stage
FROM runtime-base as final

# Copy binary from builder
COPY --from=builder /app/bin/collector /usr/local/bin/collector

# Copy default configuration
COPY configs/default.yaml /etc/ibmmq-collector/config.yaml

# Set up directories with proper permissions
RUN mkdir -p /var/log/ibmmq-collector /var/lib/ibmmq-collector && \
    chown -R ibmmq:ibmmq /var/log/ibmmq-collector /var/lib/ibmmq-collector

# Set environment variables
ENV PATH="/usr/local/bin:$PATH"
ENV CONFIG_PATH="/etc/ibmmq-collector/config.yaml"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9090/metrics || exit 1

# Expose Prometheus metrics port
EXPOSE 9090

# Switch to non-root user
USER ibmmq

# Default command
ENTRYPOINT ["collector"]
CMD ["--config", "/etc/ibmmq-collector/config.yaml", "--continuous"]

# Metadata
LABEL org.opencontainers.image.title="IBM MQ Statistics Collector"
LABEL org.opencontainers.image.description="Prometheus collector for IBM MQ statistics and accounting data"
LABEL org.opencontainers.image.vendor="IBM MQ Statistics Collector"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.source="https://github.com/atulksin/ibmmq-go-stat-otel"