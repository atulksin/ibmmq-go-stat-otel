# Makefile for IBM MQ Statistics Collector with BuildKit optimization

# Variables
APP_NAME := ibmmq-collector
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
LDFLAGS := -X main.version=$(VERSION) -X main.commit=$(GIT_COMMIT) -X main.date=$(BUILD_TIME)

# Docker settings  
DOCKER_IMAGE := $(APP_NAME)
DOCKER_TAG := $(VERSION)
REGISTRY ?= 

# BuildKit settings
export DOCKER_BUILDKIT := 1
export BUILDKIT_PROGRESS := plain

# Go settings
GOFLAGS := -ldflags "$(LDFLAGS)"
MAIN_PACKAGE := ./cmd/collector

# Directories
DIST_DIR := dist
CONFIG_DIR := configs
SCRIPTS_DIR := scripts

# Default target
.DEFAULT_GOAL := help

## help: Display this help message
.PHONY: help
help:
	@echo "IBM MQ Statistics Collector Build System"
	@echo "========================================"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Variables:"
	@echo "  VERSION     = $(VERSION)"
	@echo "  BUILD_TIME  = $(BUILD_TIME)" 
	@echo "  GIT_COMMIT  = $(GIT_COMMIT)"
	@echo "  REGISTRY    = $(REGISTRY)"

## clean: Remove build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(DIST_DIR)
	docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true
	docker rmi $(DOCKER_IMAGE):latest 2>/dev/null || true
	go clean -cache
	@echo "✅ Clean complete"

## test: Run all tests
.PHONY: test
test:
	@echo "🧪 Running tests..."
	go test -v -race -coverprofile=coverage.out ./pkg/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Tests complete"

## test-short: Run tests without race detection (faster)
.PHONY: test-short
test-short:
	@echo "🧪 Running short tests..."
	go test -v ./pkg/config ./pkg/pcf
	@echo "✅ Tests complete"

## lint: Run linting
.PHONY: lint
lint:
	@echo "🔍 Running linting..."
	@command -v golangci-lint >/dev/null 2>&1 || { \
		echo "Installing golangci-lint..."; \
		curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell go env GOPATH)/bin v1.54.2; \
	}
	golangci-lint run
	@echo "✅ Linting complete"

## build: Build binary for current platform  
.PHONY: build
build:
	@echo "🔨 Building $(APP_NAME) for current platform..."
	mkdir -p $(DIST_DIR)
	CGO_ENABLED=1 go build $(GOFLAGS) -o $(DIST_DIR)/$(APP_NAME) $(MAIN_PACKAGE)
	@echo "✅ Build complete: $(DIST_DIR)/$(APP_NAME)"

## build-cross: Build binaries for multiple platforms (CGO disabled)
.PHONY: build-cross
build-cross:
	@echo "🔨 Building $(APP_NAME) for multiple platforms..."
	mkdir -p $(DIST_DIR)
	GOOS=linux   GOARCH=amd64 CGO_ENABLED=0 go build $(GOFLAGS) -o $(DIST_DIR)/$(APP_NAME)-linux-amd64 $(MAIN_PACKAGE)
	GOOS=linux   GOARCH=arm64 CGO_ENABLED=0 go build $(GOFLAGS) -o $(DIST_DIR)/$(APP_NAME)-linux-arm64 $(MAIN_PACKAGE)  
	GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build $(GOFLAGS) -o $(DIST_DIR)/$(APP_NAME)-windows-amd64.exe $(MAIN_PACKAGE)
	GOOS=darwin  GOARCH=amd64 CGO_ENABLED=0 go build $(GOFLAGS) -o $(DIST_DIR)/$(APP_NAME)-darwin-amd64 $(MAIN_PACKAGE)
	GOOS=darwin  GOARCH=arm64 CGO_ENABLED=0 go build $(GOFLAGS) -o $(DIST_DIR)/$(APP_NAME)-darwin-arm64 $(MAIN_PACKAGE)
	@echo "✅ Cross-compilation complete"
	ls -la $(DIST_DIR)/

## docker-build: Build Docker image with BuildKit
.PHONY: docker-build
docker-build:
	@echo "🐳 Building Docker image with BuildKit..."
	docker build \
		--cache-from=$(DOCKER_IMAGE):cache \
		--cache-from=$(DOCKER_IMAGE):latest \
		--target=final \
		--build-arg VERSION=$(VERSION) \
		--build-arg BUILD_TIME=$(BUILD_TIME) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		-t $(DOCKER_IMAGE):latest \
		.
	@echo "✅ Docker build complete"

## docker-build-test: Build and run test Docker image  
.PHONY: docker-build-test
docker-build-test:
	@echo "🐳 Building test Docker image..."
	docker build \
		--target=test \
		--build-arg VERSION=$(VERSION) \
		-t $(DOCKER_IMAGE):test \
		.
	docker run --rm $(DOCKER_IMAGE):test
	@echo "✅ Docker test build complete"

## docker-push: Push Docker image to registry
.PHONY: docker-push  
docker-push: docker-build
	@if [ -z "$(REGISTRY)" ]; then \
		echo "❌ REGISTRY not set. Use: make docker-push REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	@echo "🚀 Pushing to $(REGISTRY)..."
	docker tag $(DOCKER_IMAGE):$(DOCKER_TAG) $(REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	docker tag $(DOCKER_IMAGE):latest $(REGISTRY)/$(DOCKER_IMAGE):latest
	docker push $(REGISTRY)/$(DOCKER_IMAGE):$(DOCKER_TAG)
	docker push $(REGISTRY)/$(DOCKER_IMAGE):latest
	@echo "✅ Push complete"

## docker-run: Run Docker container locally
.PHONY: docker-run
docker-run:
	@echo "🏃 Running Docker container..."
	docker run --rm -it \
		-p 9090:9090 \
		-v $(shell pwd)/$(CONFIG_DIR):/etc/ibmmq-collector:ro \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		--config /etc/ibmmq-collector/default.yaml \
		--log-level debug

## compose-up: Start services with docker-compose
.PHONY: compose-up
compose-up:
	@echo "🚀 Starting services with docker-compose..."
	docker-compose up -d
	@echo "✅ Services started"
	docker-compose ps

## compose-down: Stop docker-compose services  
.PHONY: compose-down
compose-down:
	@echo "🛑 Stopping docker-compose services..."
	docker-compose down
	@echo "✅ Services stopped"

## compose-logs: Show docker-compose logs
.PHONY: compose-logs
compose-logs:
	docker-compose logs -f

## dev: Quick development build and test
.PHONY: dev
dev: test-short build
	@echo "🚀 Development build complete"
	@echo "Run: ./$(DIST_DIR)/$(APP_NAME) --help"

## release: Full release build (test, lint, build, docker)
.PHONY: release  
release: clean test lint build-cross docker-build
	@echo "🎉 Release build complete!"
	@echo "Version: $(VERSION)"
	@echo "Binaries: $(DIST_DIR)/"
	@echo "Docker: $(DOCKER_IMAGE):$(DOCKER_TAG)"

## install: Install binary to GOPATH/bin
.PHONY: install
install:
	@echo "📦 Installing $(APP_NAME)..."
	CGO_ENABLED=1 go install $(GOFLAGS) $(MAIN_PACKAGE)
	@echo "✅ Installed to $(shell go env GOPATH)/bin/$(APP_NAME)"

## deps: Download and verify dependencies
.PHONY: deps
deps:
	@echo "📥 Downloading dependencies..."
	go mod download
	go mod verify
	@echo "✅ Dependencies ready"

## update-deps: Update dependencies to latest versions
.PHONY: update-deps
update-deps:
	@echo "🔄 Updating dependencies..."
	go get -u ./...
	go mod tidy
	@echo "✅ Dependencies updated"

## security: Run security scan
.PHONY: security
security:
	@echo "🔒 Running security scan..."
	@command -v gosec >/dev/null 2>&1 || { \
		echo "Installing gosec..."; \
		go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest; \
	}
	gosec ./...
	@echo "✅ Security scan complete"

## format: Format code
.PHONY: format  
format:
	@echo "🎨 Formatting code..."
	go fmt ./...
	@command -v goimports >/dev/null 2>&1 || go install golang.org/x/tools/cmd/goimports@latest
	goimports -w .
	@echo "✅ Code formatted"

## check: Run all checks (test, lint, security, format)
.PHONY: check
check: format test lint security
	@echo "✅ All checks passed!"

# Phony targets to prevent conflicts with files of same name  
.PHONY: all build test clean install deps