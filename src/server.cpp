#include "server.hpp"
#include <iostream>
#include <fstream>
#include <sstream>
#include <chrono>
#include <boost/algorithm/string.hpp>

ThumbnailServer::ThumbnailServer(int port, int thread_count)
    : port_(port), thread_count_(thread_count), ioc_(thread_count) {
}

ThumbnailServer::~ThumbnailServer() {
    stop();
}

void ThumbnailServer::run() {
    try {
        // Create acceptor
        acceptor_ = std::make_unique<tcp::acceptor>(ioc_, tcp::endpoint{tcp::v4(), static_cast<unsigned short>(port_)});
        
        // Set socket options
        acceptor_->set_option(tcp::acceptor::reuse_address(true));
        
        running_ = true;
        
        // Start accepting connections
        do_accept();
        
        // Start worker threads
        for (int i = 0; i < thread_count_; ++i) {
            threads_.emplace_back([this] {
                ioc_.run();
            });
        }
        
        std::cout << "Server running on port " << port_ << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "Error starting server: " << e.what() << std::endl;
        throw;
    }
}

void ThumbnailServer::stop() {
    if (!running_) return;
    
    running_ = false;
    
    if (acceptor_) {
        acceptor_->close();
    }
    
    ioc_.stop();
    
    for (auto& thread : threads_) {
        if (thread.joinable()) {
            thread.join();
        }
    }
    
    threads_.clear();
}

void ThumbnailServer::do_accept() {
    acceptor_->async_accept(
        [this](boost::system::error_code ec, tcp::socket socket) {
            if (!ec) {
                std::thread([this, socket = std::move(socket)]() mutable {
                    handle_session(std::move(socket));
                }).detach();
            }
            
            if (running_) {
                do_accept();
            }
        });
}

void ThumbnailServer::handle_session(tcp::socket socket) {
    try {
        beast::flat_buffer buffer;
        http::request_parser<http::dynamic_body> parser;
        parser.body_limit(20 * 1024 * 1024); // 20 MB limit
        http::read(socket, buffer, parser);
        auto req = parser.get();
        
        // Handle different request types
        if (req.method() == http::verb::post && req.target() == "/upload") {
            http::response<http::vector_body<uint8_t>> res{http::status::ok, req.version()};
            handle_upload(req, res);
            http::write(socket, res);
        } else if (req.method() == http::verb::get && req.target() == "/metrics") {
            http::response<http::string_body> res{http::status::ok, req.version()};
            handle_metrics(res);
            http::write(socket, res);
        } else if (req.method() == http::verb::get) {
            http::response<http::string_body> res{http::status::ok, req.version()};
            std::string path = req.target().to_string();
            if (path == "/") path = "/index.html";
            handle_static(path, res);
            http::write(socket, res);
        } else {
            http::response<http::string_body> res{http::status::not_found, req.version()};
            res.set(http::field::content_type, "text/plain");
            res.body() = "Not Found";
            res.prepare_payload();
            http::write(socket, res);
        }
        
        boost::system::error_code ec;
        socket.shutdown(tcp::socket::shutdown_send, ec);
        
    } catch (const std::exception& e) {
        std::cerr << "Session error: " << e.what() << std::endl;
    }
}

void ThumbnailServer::handle_upload(const http::request<http::dynamic_body>& req,
                                   http::response<http::vector_body<uint8_t>>& res) {
    auto start_time = std::chrono::high_resolution_clock::now();
    
    try {
        // Parse multipart form data
        std::string content_type = req[http::field::content_type].to_string();
        
        if (content_type.find("multipart/form-data") == std::string::npos) {
            res.result(http::status::bad_request);
            return;
        }
        
        // Extract boundary
        std::string boundary;
        size_t boundary_pos = content_type.find("boundary=");
        if (boundary_pos != std::string::npos) {
            boundary = content_type.substr(boundary_pos + 9);
        } else {
            res.result(http::status::bad_request);
            return;
        }
        
        // Parse multipart body
        std::string body_str = boost::beast::buffers_to_string(req.body().data());
        std::vector<uint8_t> image_data;
        
        // Find file data in multipart
        std::string boundary_marker = "--" + boundary;
        size_t pos = body_str.find(boundary_marker);
        if (pos == std::string::npos) {
            res.result(http::status::bad_request);
            return;
        }
        
        // Find the start of file data
        pos = body_str.find("\r\n\r\n", pos);
        if (pos == std::string::npos) {
            res.result(http::status::bad_request);
            return;
        }
        pos += 4;
        
        // Find the end of file data
        size_t end_pos = body_str.find(boundary_marker, pos);
        if (end_pos == std::string::npos) {
            res.result(http::status::bad_request);
            return;
        }
        
        // Extract image data (remove trailing \r\n)
        while (end_pos > pos && (body_str[end_pos-1] == '\n' || body_str[end_pos-1] == '\r')) {
            end_pos--;
        }
        
        image_data.assign(body_str.begin() + pos, body_str.begin() + end_pos);
        
        // Process thumbnail
        auto process_start = std::chrono::high_resolution_clock::now();
        std::vector<uint8_t> thumbnail = processor_.create_thumbnail(image_data, 100, 100);
        auto process_end = std::chrono::high_resolution_clock::now();
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto total_duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
        auto process_duration = std::chrono::duration_cast<std::chrono::microseconds>(process_end - process_start);
        
        // Record metrics
        metrics_.record_request(total_duration.count(), process_duration.count());
        
        // Set response
        res.set(http::field::content_type, "image/png");
        res.set(http::field::access_control_allow_origin, "*");
        res.body() = std::move(thumbnail);
        res.prepare_payload();
        
    } catch (const std::exception& e) {
        std::cerr << "Upload processing error: " << e.what() << std::endl;
        res.result(http::status::internal_server_error);
    }
}

void ThumbnailServer::handle_metrics(http::response<http::string_body>& res) {
    res.set(http::field::content_type, "text/plain");
    res.body() = metrics_.get_prometheus_metrics();
    res.prepare_payload();
}

void ThumbnailServer::handle_static(const std::string& path, http::response<http::string_body>& res) {
    std::string content = get_static_content(path);
    
    if (content.empty()) {
        res.result(http::status::not_found);
        res.set(http::field::content_type, "text/plain");
        res.body() = "Not Found";
    } else {
        if (path.find(".html") != std::string::npos) {
            res.set(http::field::content_type, "text/html");
        } else if (path.find(".css") != std::string::npos) {
            res.set(http::field::content_type, "text/css");
        } else if (path.find(".js") != std::string::npos) {
            res.set(http::field::content_type, "application/javascript");
        }
        res.body() = content;
    }
    
    res.prepare_payload();
}

std::string ThumbnailServer::get_static_content(const std::string& path) {
    if (path == "/index.html") {
        return R"(
<!DOCTYPE html>
<html>
<head>
    <title>ThumbnailGen - Fast Image Thumbnailing</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 8px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
            margin-bottom: 30px;
        }
        #drop {
            width: 100%;
            height: 200px;
            border: 3px dashed #ddd;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 18px;
            color: #666;
            transition: all 0.3s ease;
            margin-bottom: 20px;
        }
        #drop.dragover {
            border-color: #007bff;
            background: #f8f9fa;
            color: #007bff;
        }
        .results {
            display: flex;
            gap: 20px;
            flex-wrap: wrap;
        }
        .image-container {
            text-align: center;
        }
        .image-container img {
            max-width: 200px;
            max-height: 200px;
            border-radius: 4px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .image-container h3 {
            margin: 10px 0 5px 0;
            color: #333;
        }
        .stats {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            margin-top: 20px;
            font-family: monospace;
        }
        .error {
            color: #dc3545;
            background: #f8d7da;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ThumbnailGen - Ultra-Fast Image Processing</h1>
        <div id="drop">Drop an image here or click to select</div>
        <div id="output" class="results"></div>
        <div id="stats" class="stats" style="display: none;"></div>
    </div>

    <script>
        const drop = document.getElementById('drop');
        const output = document.getElementById('output');
        const stats = document.getElementById('stats');

        // Handle drag and drop
        drop.addEventListener('dragover', e => {
            e.preventDefault();
            drop.classList.add('dragover');
        });

        drop.addEventListener('dragleave', e => {
            e.preventDefault();
            drop.classList.remove('dragover');
        });

        drop.addEventListener('drop', e => {
            e.preventDefault();
            drop.classList.remove('dragover');
            const file = e.dataTransfer.files[0];
            if (file) processFile(file);
        });

        // Handle click to select
        drop.addEventListener('click', () => {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.onchange = (e) => {
                const file = e.target.files[0];
                if (file) processFile(file);
            };
            input.click();
        });

        async function processFile(file) {
            // Clear previous results
            output.innerHTML = '';
            stats.style.display = 'none';

            // Show original image
            const origURL = URL.createObjectURL(file);
            const origContainer = document.createElement('div');
            origContainer.className = 'image-container';
            origContainer.innerHTML = `
                <h3>Original (${(file.size / 1024).toFixed(1)} KB)</h3>
                <img src="${origURL}" alt="Original">
            `;
            output.appendChild(origContainer);

            // Show loading state
            const loadingContainer = document.createElement('div');
            loadingContainer.className = 'image-container';
            loadingContainer.innerHTML = `
                <h3>Thumbnail</h3>
                <div style="width: 100px; height: 100px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; border-radius: 4px;">
                    Processing...
                </div>
            `;
            output.appendChild(loadingContainer);

            try {
                const form = new FormData();
                form.append('file', file);

                const start = performance.now();
                const resp = await fetch('/upload', { method: 'POST', body: form });
                const end = performance.now();

                if (!resp.ok) {
                    throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
                }

                const blob = await resp.blob();
                const duration = end - start;

                // Update thumbnail
                const thumbURL = URL.createObjectURL(blob);
                loadingContainer.innerHTML = `
                    <h3>Thumbnail (${(blob.size / 1024).toFixed(1)} KB)</h3>
                    <img src="${thumbURL}" alt="Thumbnail">
                `;

                // Show stats
                stats.style.display = 'block';
                stats.innerHTML = `
                    <strong>Performance Metrics:</strong><br>
                    Total round-trip time: ${duration.toFixed(1)} ms<br>
                    Thumbnail size: ${(blob.size / 1024).toFixed(1)} KB<br>
                    Compression ratio: ${(file.size / blob.size).toFixed(1)}:1
                `;

            } catch (error) {
                console.error('Error:', error);
                loadingContainer.innerHTML = `
                    <div class="error">
                        Error processing image: ${error.message}
                    </div>
                `;
            }
        }
    </script>
</body>
</html>
        )";
    }
    
    return "";
} 