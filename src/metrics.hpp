#pragma once

#include <atomic>
#include <chrono>
#include <string>
#include <mutex>
#include <vector>

class MetricsCollector {
public:
    MetricsCollector();
    
    // Record a request with timing information
    void record_request(int64_t total_microseconds, int64_t processing_microseconds);
    
    // Get metrics in Prometheus text format
    std::string get_prometheus_metrics() const;

private:
    // Atomic counters for thread-safe metrics
    std::atomic<int64_t> total_requests_{0};
    std::atomic<int64_t> successful_requests_{0};
    std::atomic<int64_t> failed_requests_{0};
    
    // Timing statistics (using mutex for thread safety)
    mutable std::mutex timing_mutex_;
    std::vector<int64_t> total_times_;
    std::vector<int64_t> processing_times_;
    
    // Keep only the last 1000 measurements to avoid memory bloat
    static constexpr size_t MAX_SAMPLES = 1000;
    
    // Helper methods
    void add_timing_sample(std::vector<int64_t>& samples, int64_t value);
    double calculate_percentile(const std::vector<int64_t>& samples, double percentile) const;
}; 