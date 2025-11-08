#!/bin/bash

# Enhanced build script for IBM MQ Statistics Collector with Docker BuildKit support
# Usage: ./scripts/build.sh [binary|docker|all] [version] [target]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUILD_TYPE=${1:-"all"}
VERSION=${2:-"dev"}
DOCKER_TARGET=${3:-"final"}
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
IMAGE_NAME="ibmmq-collector"

echo -e "${BLUE}🏗️  Building IBM MQ Statistics Collector${NC}"
echo -e "${YELLOW}Build type: $BUILD_TYPE${NC}"
echo -e "${YELLOW}Version: $VERSION${NC}"
echo -e "${YELLOW}Build time: $BUILD_TIME${NC}"
echo -e "${YELLOW}Git commit: $GIT_COMMIT${NC}"

# Set build flags
LDFLAGS="-X main.version=$VERSION -X main.commit=$GIT_COMMIT -X main.date=$BUILD_TIME"

# Function to build binaries
build_binaries() {
    echo -e "${BLUE}📦 Building cross-platform binaries...${NC}"
    
    # Create build directory
    mkdir -p dist
    
    # Note: IBM MQ client requires CGO, so we can't cross-compile easily
    # We'll build for the current platform with CGO for full functionality
    echo -e "${YELLOW}Building with IBM MQ client support (CGO enabled)...${NC}"
    
    # Check if we have IBM MQ development libraries
    if [ -d "/opt/mqm" ] || [ -n "$MQ_INSTALLATION_PATH" ]; then
        echo -e "${GREEN}IBM MQ libraries found, building with full MQ support${NC}"
        CGO_ENABLED=1 go build -ldflags "$LDFLAGS" -o dist/ibmmq-collector ./cmd/collector
    else
        echo -e "${YELLOW}IBM MQ libraries not found, building without CGO (limited functionality)${NC}"
        CGO_ENABLED=0 go build -ldflags "$LDFLAGS" -o dist/ibmmq-collector-no-cgo ./cmd/collector
    fi
    
    echo -e "${GREEN}✅ Binary build complete!${NC}"
    ls -la dist/
}

# Function to build Docker image with BuildKit
build_docker() {
    echo -e "${BLUE}🐳 Building Docker image with BuildKit...${NC}"
    
    # Enable BuildKit
    export DOCKER_BUILDKIT=1
    export BUILDKIT_PROGRESS=plain
    
    # Build command with optimizations
    build_cmd="docker build"
    
    # Add BuildKit cache options for faster rebuilds
    build_cmd+=" --cache-from=${IMAGE_NAME}:cache"
    build_cmd+=" --cache-from=${IMAGE_NAME}:latest"
    
    # Set target stage
    echo -e "${YELLOW}🎯 Target: ${DOCKER_TARGET}${NC}"
    build_cmd+=" --target=${DOCKER_TARGET}"
    
    # Add build arguments
    build_cmd+=" --build-arg VERSION=${VERSION}"
    build_cmd+=" --build-arg BUILD_TIME=${BUILD_TIME}"
    build_cmd+=" --build-arg GIT_COMMIT=${GIT_COMMIT}"
    
    # Add tags
    build_cmd+=" -t ${IMAGE_NAME}:${VERSION}"
    build_cmd+=" -t ${IMAGE_NAME}:latest"
    
    # Add context
    build_cmd+=" ."
    
    # Execute build
    echo -e "${BLUE}Executing: ${build_cmd}${NC}"
    eval $build_cmd
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Docker build completed successfully!${NC}"
        docker images | grep $IMAGE_NAME | head -3
        
        # Run tests if this is a test build
        if [ "$DOCKER_TARGET" = "test" ]; then
            echo -e "${BLUE}🧪 Running tests...${NC}"
            docker run --rm ${IMAGE_NAME}:${VERSION}
        fi
    else
        echo -e "${RED}❌ Docker build failed!${NC}"
        exit 1
    fi
}

# Function to run tests
run_tests() {
    echo -e "${BLUE}🧪 Running tests...${NC}"
    go test -v ./pkg/config ./pkg/pcf
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
    else
        echo -e "${RED}❌ Tests failed!${NC}"
        exit 1
    fi
}

# Main build logic
case $BUILD_TYPE in
    "binary")
        build_binaries
        ;;
    "docker")
        build_docker
        ;;
    "test")
        run_tests
        ;;
    "docker-test")
        DOCKER_TARGET="test"
        build_docker
        ;;
    "all")
        echo -e "${BLUE}🚀 Building everything...${NC}"
        run_tests
        build_binaries
        build_docker
        ;;
    *)
        echo -e "${RED}❌ Unknown build type: $BUILD_TYPE${NC}"
        echo -e "${YELLOW}Usage: $0 [binary|docker|test|docker-test|all] [version] [docker_target]${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Build process complete!${NC}"