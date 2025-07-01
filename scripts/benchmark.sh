#!/bin/bash

# ThumbnailGen Benchmark Script
# This script performs comprehensive performance testing

set -e

# Configuration
SERVICE_URL="http://localhost:8080"
TEST_IMAGE="test_image.jpg"
DURATION=30
THREADS=4
CONNECTIONS=50

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v wrk &> /dev/null; then
        log_error "wrk is required but not installed. Install with: sudo apt-get install wrk"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found, some features may be limited"
    fi
}

check_service() {
    log_info "Checking if service is running..."
    
    if ! curl -s -f "$SERVICE_URL/metrics" > /dev/null; then
        log_error "Service is not running at $SERVICE_URL"
        log_info "Start the service with: ./thumbnail_service --port 8080"
        exit 1
    fi
    
    log_success "Service is running"
}

create_test_image() {
    if [ ! -f "$TEST_IMAGE" ]; then
        log_info "Creating test image..."
        
        # Create a simple test image using ImageMagick if available
        if command -v convert &> /dev/null; then
            convert -size 1920x1080 xc:white -fill black -pointsize 72 -gravity center -annotate 0 "Test Image" "$TEST_IMAGE"
            log_success "Created test image using ImageMagick"
        else
            log_warning "ImageMagick not found, please create a test image manually"
            log_info "You can download a test image or create one with:"
            log_info "  wget https://picsum.photos/1920/1080 -O $TEST_IMAGE"
            exit 1
        fi
    else
        log_info "Using existing test image: $TEST_IMAGE"
    fi
}

run_single_request_test() {
    log_info "Running single request test..."
    
    local start_time=$(date +%s%3N)
    local response=$(curl -s -w "%{http_code}" -F "file=@$TEST_IMAGE" "$SERVICE_URL/upload" -o /tmp/thumbnail.png)
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [ "$response" = "200" ]; then
        local size=$(stat -c%s /tmp/thumbnail.png)
        log_success "Single request completed in ${duration}ms (thumbnail size: ${size} bytes)"
        echo "$duration" > /tmp/single_request_time.txt
    else
        log_error "Single request failed with HTTP $response"
        exit 1
    fi
}

run_load_test() {
    log_info "Running load test with wrk..."
    log_info "Parameters: $THREADS threads, $CONNECTIONS connections, ${DURATION}s duration"
    
    # Run wrk load test
    wrk -t$THREADS -c$CONNECTIONS -d${DURATION}s -s scripts/post.lua "$SERVICE_URL/upload" > /tmp/wrk_output.txt 2>&1
    
    if [ $? -eq 0 ]; then
        log_success "Load test completed"
        cat /tmp/wrk_output.txt
    else
        log_error "Load test failed"
        cat /tmp/wrk_output.txt
        exit 1
    fi
}

get_metrics() {
    log_info "Fetching current metrics..."
    
    local metrics=$(curl -s "$SERVICE_URL/metrics")
    
    # Extract key metrics
    local total_requests=$(echo "$metrics" | grep "thumbnail_requests_total" | grep -v "#" | awk '{print $2}')
    local p99_latency=$(echo "$metrics" | grep "thumbnail_p99_latency_ms" | grep -v "#" | awk '{print $2}')
    local performance_status=$(echo "$metrics" | grep "thumbnail_performance_status" | grep -v "#" | awk '{print $2}')
    
    echo "Total requests: $total_requests" > /tmp/current_metrics.txt
    echo "P99 latency: ${p99_latency}ms" >> /tmp/current_metrics.txt
    echo "Performance goal met: $([ "$performance_status" = "1" ] && echo "YES" || echo "NO")" >> /tmp/current_metrics.txt
}

generate_report() {
    log_info "Generating benchmark report..."
    
    local report_file="benchmark_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "ThumbnailGen Benchmark Report"
        echo "============================"
        echo "Date: $(date)"
        echo "Service URL: $SERVICE_URL"
        echo "Test Image: $TEST_IMAGE ($(stat -c%s "$TEST_IMAGE") bytes)"
        echo ""
        echo "Configuration:"
        echo "  Threads: $THREADS"
        echo "  Connections: $CONNECTIONS"
        echo "  Duration: ${DURATION}s"
        echo ""
        echo "Single Request Test:"
        if [ -f /tmp/single_request_time.txt ]; then
            echo "  Duration: $(cat /tmp/single_request_time.txt)ms"
        fi
        echo ""
        echo "Load Test Results:"
        if [ -f /tmp/wrk_output.txt ]; then
            cat /tmp/wrk_output.txt
        fi
        echo ""
        echo "Current Metrics:"
        if [ -f /tmp/current_metrics.txt ]; then
            cat /tmp/current_metrics.txt
        fi
        echo ""
        echo "Performance Analysis:"
        if [ -f /tmp/current_metrics.txt ]; then
            local p99_latency=$(grep "P99 latency" /tmp/current_metrics.txt | awk '{print $3}' | sed 's/ms//')
            if (( $(echo "$p99_latency < 50" | bc -l) )); then
                echo "  ✅ P99 latency ($p99_latency ms) meets <50ms goal"
            else
                echo "  ❌ P99 latency ($p99_latency ms) exceeds <50ms goal"
            fi
        fi
    } > "$report_file"
    
    log_success "Benchmark report saved to: $report_file"
    echo ""
    cat "$report_file"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f /tmp/thumbnail.png /tmp/single_request_time.txt /tmp/wrk_output.txt /tmp/current_metrics.txt
}

# Main execution
main() {
    echo "🚀 ThumbnailGen Benchmark Suite"
    echo "================================"
    echo ""
    
    check_dependencies
    check_service
    create_test_image
    
    # Run tests
    run_single_request_test
    run_load_test
    get_metrics
    
    # Generate report
    generate_report
    
    # Cleanup
    cleanup
    
    log_success "Benchmark completed successfully!"
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            SERVICE_URL="$2"
            shift 2
            ;;
        --image)
            TEST_IMAGE="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --connections)
            CONNECTIONS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --url URL         Service URL (default: http://localhost:8080)"
            echo "  --image FILE      Test image file (default: test_image.jpg)"
            echo "  --duration SEC    Test duration in seconds (default: 30)"
            echo "  --threads N       Number of wrk threads (default: 4)"
            echo "  --connections N   Number of connections (default: 50)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@" 