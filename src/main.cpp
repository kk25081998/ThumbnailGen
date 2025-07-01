#include <iostream>
#include <signal.h>
#include <thread>
#include <atomic>
#include "server.hpp"

std::atomic<bool> running{true};

void signal_handler(int signal) {
    std::cout << "Received signal " << signal << ", shutting down..." << std::endl;
    running = false;
}

int main(int argc, char* argv[]) {

    // Set up signal handling
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);

    try {
        // Parse command line arguments
        int port = 8080;
        int threads = std::thread::hardware_concurrency();
        
        for (int i = 1; i < argc; i++) {
            std::string arg = argv[i];
            if (arg == "--port" && i + 1 < argc) {
                port = std::stoi(argv[++i]);
            } else if (arg == "--threads" && i + 1 < argc) {
                threads = std::stoi(argv[++i]);
            } else if (arg == "--help") {
                std::cout << "Usage: " << argv[0] << " [--port PORT] [--threads THREADS]" << std::endl;
                std::cout << "  --port PORT     Port to listen on (default: 8080)" << std::endl;
                std::cout << "  --threads THREADS Number of worker threads (default: CPU cores)" << std::endl;
                return 0;
            }
        }

        std::cout << "Starting ThumbnailGen service on port " << port 
                  << " with " << threads << " threads" << std::endl;

        // Create and run server
        ThumbnailServer server(port, threads);
        server.run();

        // Wait for shutdown signal
        while (running) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }

        std::cout << "Shutting down server..." << std::endl;
        server.stop();

    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }

    std::cout << "Server stopped successfully" << std::endl;
    return 0;
} 