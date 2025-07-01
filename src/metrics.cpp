#include "metrics.hpp"
#include <sstream>
#include <algorithm>
#include <numeric>
#include <iomanip>

MetricsCollector::MetricsCollector() {
}

void MetricsCollector::record_request(int64_t total_microseconds, int64_t processing_microseconds) {
    total_requests_++;
    successful_requests_++;
    
    std::lock_guard<std::mutex> lock(timing_mutex_);
    add_timing_sample(total_times_, total_microseconds);
    add_timing_sample(processing_times_, processing_microseconds);
}

void MetricsCollector::add_timing_sample(std::vector<int64_t>& samples, int64_t value) {
    samples.push_back(value);
    if (samples.size() > MAX_SAMPLES) {
        samples.erase(samples.begin());
    }
}

double MetricsCollector::calculate_percentile(const std::vector<int64_t>& samples, double percentile) const {
    if (samples.empty()) return 0.0;
    
    std::vector<int64_t> sorted_samples = samples;
    std::sort(sorted_samples.begin(), sorted_samples.end());
    
    size_t index = static_cast<size_t>(percentile * (sorted_samples.size() - 1));
    return static_cast<double>(sorted_samples[index]);
}

std::string MetricsCollector::get_prometheus_metrics() const {
    std::ostringstream oss;
    
    // Request counters
    oss << "# HELP thumbnail_requests_total Total number of thumbnail requests\n";
    oss << "# TYPE thumbnail_requests_total counter\n";
    oss << "thumbnail_requests_total " << total_requests_.load() << "\n\n";
    
    oss << "# HELP thumbnail_requests_successful_total Total number of successful thumbnail requests\n";
    oss << "# TYPE thumbnail_requests_successful_total counter\n";
    oss << "thumbnail_requests_successful_total " << successful_requests_.load() << "\n\n";
    
    oss << "# HELP thumbnail_requests_failed_total Total number of failed thumbnail requests\n";
    oss << "# TYPE thumbnail_requests_failed_total counter\n";
    oss << "thumbnail_requests_failed_total " << failed_requests_.load() << "\n\n";
    
    // Timing histograms
    std::lock_guard<std::mutex> lock(timing_mutex_);
    
    if (!total_times_.empty()) {
        oss << "# HELP thumbnail_request_duration_microseconds Total request duration in microseconds\n";
        oss << "# TYPE thumbnail_request_duration_microseconds histogram\n";
        
        double p50 = calculate_percentile(total_times_, 0.5);
        double p95 = calculate_percentile(total_times_, 0.95);
        double p99 = calculate_percentile(total_times_, 0.99);
        
        double sum = std::accumulate(total_times_.begin(), total_times_.end(), 0.0);
        double mean = sum / total_times_.size();
        
        oss << "thumbnail_request_duration_microseconds{quantile=\"0.5\"} " << std::fixed << std::setprecision(2) << p50 << "\n";
        oss << "thumbnail_request_duration_microseconds{quantile=\"0.95\"} " << std::fixed << std::setprecision(2) << p95 << "\n";
        oss << "thumbnail_request_duration_microseconds{quantile=\"0.99\"} " << std::fixed << std::setprecision(2) << p99 << "\n";
        oss << "thumbnail_request_duration_microseconds_sum " << std::fixed << std::setprecision(2) << sum << "\n";
        oss << "thumbnail_request_duration_microseconds_count " << total_times_.size() << "\n\n";
    }
    
    if (!processing_times_.empty()) {
        oss << "# HELP thumbnail_processing_duration_microseconds Image processing duration in microseconds\n";
        oss << "# TYPE thumbnail_processing_duration_microseconds histogram\n";
        
        double p50 = calculate_percentile(processing_times_, 0.5);
        double p95 = calculate_percentile(processing_times_, 0.95);
        double p99 = calculate_percentile(processing_times_, 0.99);
        
        double sum = std::accumulate(processing_times_.begin(), processing_times_.end(), 0.0);
        double mean = sum / processing_times_.size();
        
        oss << "thumbnail_processing_duration_microseconds{quantile=\"0.5\"} " << std::fixed << std::setprecision(2) << p50 << "\n";
        oss << "thumbnail_processing_duration_microseconds{quantile=\"0.95\"} " << std::fixed << std::setprecision(2) << p95 << "\n";
        oss << "thumbnail_processing_duration_microseconds{quantile=\"0.99\"} " << std::fixed << std::setprecision(2) << p99 << "\n";
        oss << "thumbnail_processing_duration_microseconds_sum " << std::fixed << std::setprecision(2) << sum << "\n";
        oss << "thumbnail_processing_duration_microseconds_count " << processing_times_.size() << "\n\n";
    }
    
    // Current performance status
    if (!total_times_.empty()) {
        double p99_ms = calculate_percentile(total_times_, 0.99) / 1000.0;
        oss << "# HELP thumbnail_performance_status Current performance status (1 = meeting <50ms goal)\n";
        oss << "# TYPE thumbnail_performance_status gauge\n";
        oss << "thumbnail_performance_status " << (p99_ms < 50.0 ? 1.0 : 0.0) << "\n\n";
        
        oss << "# HELP thumbnail_p99_latency_ms 99th percentile latency in milliseconds\n";
        oss << "# TYPE thumbnail_p99_latency_ms gauge\n";
        oss << "thumbnail_p99_latency_ms " << std::fixed << std::setprecision(2) << p99_ms << "\n";
    }
    
    return oss.str();
} 