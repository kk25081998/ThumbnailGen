#include "server.hpp"
#include <iostream>
#include <fstream>
#include <sstream>
#include <chrono>
#include <boost/algorithm/string.hpp>
#include <regex>

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
        auto session_start = std::chrono::high_resolution_clock::now();
        beast::flat_buffer buffer;
        http::request_parser<http::dynamic_body> parser;
        parser.body_limit(20 * 1024 * 1024); // 20 MB limit
        http::read(socket, buffer, parser);
        auto req = parser.get();
        auto upload_start = std::chrono::high_resolution_clock::now();
        // Parse query parameters for /upload
        std::string format = "png";
        std::string size = "medium";
        int target_width = 128, target_height = 128;
        if (req.method() == http::verb::post && req.target().starts_with("/upload")) {
            std::string target = req.target().to_string();
            size_t qpos = target.find('?');
            if (qpos != std::string::npos) {
                std::string query = target.substr(qpos + 1);
                std::regex param_regex("([a-zA-Z0-9_]+)=([^&]*)");
                auto params_begin = std::sregex_iterator(query.begin(), query.end(), param_regex);
                auto params_end = std::sregex_iterator();
                for (auto it = params_begin; it != params_end; ++it) {
                    std::string key = (*it)[1];
                    std::string value = (*it)[2];
                    if (key == "format") format = value;
                    if (key == "size") size = value;
                }
            }
            if (size == "small") { target_width = target_height = 64; }
            else if (size == "large") { target_width = target_height = 256; }
            // else medium (default) is 128x128
        }
        // Handle different request types
        if (req.method() == http::verb::post && req.target().starts_with("/upload")) {
            http::response<http::vector_body<uint8_t>> res{http::status::ok, req.version()};
            res.set(http::field::connection, "keep-alive");
            handle_upload(req, res, format, target_width, target_height);
            http::write(socket, res);
        } else if (req.method() == http::verb::get && req.target() == "/metrics") {
            http::response<http::string_body> res{http::status::ok, req.version()};
            res.set(http::field::connection, "keep-alive");
            handle_metrics(res);
            http::write(socket, res);
        } else if (req.method() == http::verb::get) {
            http::response<http::string_body> res{http::status::ok, req.version()};
            res.set(http::field::connection, "keep-alive");
            std::string path = req.target().to_string();
            if (path == "/") path = "/index.html";
            handle_static(path, res);
            http::write(socket, res);
        } else {
            http::response<http::string_body> res{http::status::not_found, req.version()};
            res.set(http::field::content_type, "text/plain");
            res.set(http::field::connection, "keep-alive");
            res.body() = "Not Found";
            res.prepare_payload();
            http::write(socket, res);
        }
        auto session_end = std::chrono::high_resolution_clock::now();
        auto session_duration = std::chrono::duration_cast<std::chrono::microseconds>(session_end - session_start);
        std::cout << "[Timing] Total session time: " << session_duration.count() / 1000.0 << " ms" << std::endl;
        boost::system::error_code ec;
        socket.shutdown(tcp::socket::shutdown_send, ec);
    } catch (const std::exception& e) {
        std::cerr << "Session error: " << e.what() << std::endl;
    }
}

void ThumbnailServer::handle_upload(const http::request<http::dynamic_body>& req,
                                   http::response<http::vector_body<uint8_t>>& res,
                                   const std::string& format,
                                   int target_width,
                                   int target_height) {
    auto start_time = std::chrono::high_resolution_clock::now();
    try {
        // CLIENT-SIDE OPTIMIZATION SUGGESTION:
        // For best performance, clients should compress and/or resize images before upload if possible.
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
        auto upload_end = std::chrono::high_resolution_clock::now();
        // Process thumbnail
        auto process_start = std::chrono::high_resolution_clock::now();
        std::vector<uint8_t> thumbnail = processor_.create_thumbnail(image_data, target_width, target_height, format);
        auto process_end = std::chrono::high_resolution_clock::now();
        auto end_time = std::chrono::high_resolution_clock::now();
        auto upload_duration = std::chrono::duration_cast<std::chrono::microseconds>(upload_end - start_time);
        auto process_duration = std::chrono::duration_cast<std::chrono::microseconds>(process_end - process_start);
        auto response_duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - process_end);
        auto total_duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
        // Record metrics
        metrics_.record_request(total_duration.count(), process_duration.count());
        // Timing logs
        std::cout << "[Timing] Upload: " << upload_duration.count() / 1000.0 << " ms, "
                  << "Processing: " << process_duration.count() / 1000.0 << " ms, "
                  << "Response: " << response_duration.count() / 1000.0 << " ms, "
                  << "Total: " << total_duration.count() / 1000.0 << " ms" << std::endl;
        // Set response Content-Type
        if (format == "jpeg")
            res.set(http::field::content_type, "image/jpeg");
        else if (format == "webp")
            res.set(http::field::content_type, "image/webp");
        else
            res.set(http::field::content_type, "image/png");
        res.set(http::field::access_control_allow_origin, "*");
        res.set(http::field::connection, "keep-alive");
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
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>ThumbnailGen - Fast Image Thumbnailing</title>
    <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Ctext y='52' font-size='52'%3E🚀%3C/text%3E%3C/svg%3E">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            border-radius: 14px;
            padding: 36px 24px 28px 24px;
            box-shadow: 0 2px 18px rgba(0,0,0,0.10);
            margin-top: 32px;
            transition: box-shadow 0.2s;
        }
        h1 {
            color: #007bff;
            text-align: center;
            margin-bottom: 18px;
            font-size: 2.1rem;
            letter-spacing: 0.5px;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }
        .step {
            margin-bottom: 18px;
        }
        .step label {
            font-weight: 500;
            margin-right: 8px;
        }
        .info {
            font-size: 0.95em;
            color: #666;
            margin-left: 6px;
            cursor: pointer;
            border-bottom: 1px dotted #666;
        }
        #drop {
            width: 100%;
            min-height: 120px;
            border: 2.5px dashed #007bff;
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.1em;
            color: #007bff;
            background: #f8faff;
            margin-bottom: 10px;
            transition: border-color 0.2s, background 0.2s;
            outline: none;
        }
        #drop.dragover {
            border-color: #0056b3;
            background: #e6f0ff;
        }
        #drop:focus {
            border-color: #0056b3;
            background: #e6f0ff;
        }
        #controls {
            display: flex;
            gap: 18px;
            flex-wrap: wrap;
            align-items: center;
            margin-bottom: 10px;
        }
        #controls label {
            margin-bottom: 0;
        }
        select {
            padding: 4px 8px;
            border-radius: 4px;
            border: 1px solid #ccc;
            font-size: 1em;
        }
        #generateBtn {
            background: #007bff;
            color: white;
            border: none;
            border-radius: 6px;
            padding: 10px 24px;
            font-size: 1.1em;
            cursor: pointer;
            margin-top: 10px;
            transition: background 0.2s;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        #generateBtn:disabled {
            background: #b3d1ff;
            cursor: not-allowed;
        }
        #generateBtn .spinner {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #fff;
            border-top: 3px solid #007bff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        .results {
            display: flex;
            gap: 24px;
            flex-wrap: wrap;
            justify-content: center;
            margin-top: 24px;
            transition: opacity 0.3s;
        }
        .image-container {
            text-align: center;
            flex: 1 1 180px;
        }
        .image-container img {
            max-width: 180px;
            max-height: 180px;
            border-radius: 6px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
            margin-bottom: 6px;
        }
        .image-container h3 {
            margin: 10px 0 5px 0;
            color: #333;
            font-size: 1em;
        }
        .meta {
            font-size: 0.95em;
            color: #888;
            margin-bottom: 4px;
        }
        .download-btn {
            display: inline-block;
            margin-top: 8px;
            background: #28a745;
            color: white;
            padding: 6px 16px;
            border-radius: 4px;
            text-decoration: none;
            font-size: 0.98em;
            transition: background 0.2s;
        }
        .download-btn:hover {
            background: #218838;
        }
        .stats {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            margin-top: 20px;
            font-family: monospace;
            font-size: 1em;
        }
        .error {
            color: #dc3545;
            background: #f8d7da;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
            text-align: center;
        }
        .success {
            color: #28a745;
            background: #e6f9ed;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
            text-align: center;
        }
        @media (max-width: 700px) {
            .container { padding: 12px 2vw; }
            .results { flex-direction: column; gap: 12px; }
            .image-container img { max-width: 98vw; }
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class="container">
        <h1><span aria-label="rocket" role="img">🚀</span> <span>ThumbnailGen</span></h1>
        <div class="step">
            <label for="fileInput">1. Upload Image:</label>
            <div id="drop" tabindex="0" aria-label="Drop an image here or click to select">Drop an image here or click to select</div>
        </div>
        <div class="step" id="controls">
            <label for="format">2. Format:</label>
            <select id="format" aria-label="Output format">
                <option value="png">PNG</option>
                <option value="jpeg">JPEG</option>
                <option value="webp">WebP</option>
            </select>
            <span class="info" title="PNG: best for transparency. JPEG: best for photos. WebP: modern, small size.">?</span>
            <label for="size">Size:</label>
            <select id="size" aria-label="Thumbnail size">
                <option value="small">Small (64x64)</option>
                <option value="medium" selected>Medium (128x128)</option>
                <option value="large">Large (256x256)</option>
            </select>
            <span class="info" title="Small: icons. Medium: previews. Large: detail.">?</span>
        </div>
        <button id="generateBtn" disabled aria-label="Generate Thumbnail">Generate Thumbnail</button>
        <div id="output" class="results" aria-live="polite"></div>
        <div id="stats" class="stats" style="display: none;"></div>
        <div id="error" class="error" style="display: none;"></div>
        <div id="success" class="success" style="display: none;"></div>
    </div>
    <script>
        const drop = document.getElementById('drop');
        const output = document.getElementById('output');
        const stats = document.getElementById('stats');
        const errorDiv = document.getElementById('error');
        const successDiv = document.getElementById('success');
        const formatSelect = document.getElementById('format');
        const sizeSelect = document.getElementById('size');
        const generateBtn = document.getElementById('generateBtn');
        let selectedFile = null;
        let origMeta = {};
        // Enable button only if file is selected
        function updateButtonState() {
            generateBtn.disabled = !selectedFile;
        }
        // Keyboard navigation for drop area
        drop.addEventListener('keydown', e => {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                openFileDialog();
            }
        });
        // Drag and drop
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
            if (file) selectFile(file);
        });
        // Click to select
        drop.addEventListener('click', openFileDialog);
        function openFileDialog() {
            const input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.onchange = (e) => {
                const file = e.target.files[0];
                if (file) selectFile(file);
            };
            input.click();
        }
        function selectFile(file) {
            selectedFile = file;
            updateButtonState();
            errorDiv.style.display = 'none';
            successDiv.style.display = 'none';
            output.innerHTML = '';
            stats.style.display = 'none';
            // Show original image preview and meta
            const origURL = URL.createObjectURL(file);
            const img = new window.Image();
            img.onload = function() {
                origMeta = { width: img.naturalWidth, height: img.naturalHeight, type: file.type };
                renderOriginal(origURL, file, origMeta);
            };
            img.src = origURL;
        }
        function renderOriginal(url, file, meta) {
            output.innerHTML = '';
            const origContainer = document.createElement('div');
            origContainer.className = 'image-container';
            origContainer.innerHTML = `
                <h3>Original (${(file.size / 1024).toFixed(1)} KB)</h3>
                <img src="${url}" alt="Original image preview">
                <div class="meta">${meta.type || 'Unknown type'}<br>${meta.width || '?'}×${meta.height || '?'} px</div>
            `;
            output.appendChild(origContainer);
        }
        // Generate button click
        generateBtn.addEventListener('click', async () => {
            if (!selectedFile) return;
            output.innerHTML = '';
            stats.style.display = 'none';
            errorDiv.style.display = 'none';
            successDiv.style.display = 'none';
            // Show original image preview again
            const origURL = URL.createObjectURL(selectedFile);
            renderOriginal(origURL, selectedFile, origMeta);
            // Show loading state
            const loadingContainer = document.createElement('div');
            loadingContainer.className = 'image-container';
            loadingContainer.innerHTML = `
                <h3>Thumbnail</h3>
                <div style="width: 100px; height: 100px; background: #f0f0f0; display: flex; align-items: center; justify-content: center; border-radius: 4px;">
                    <span class="spinner" aria-label="Processing"></span>
                </div>
            `;
            output.appendChild(loadingContainer);
            // Disable button and show spinner
            generateBtn.disabled = true;
            generateBtn.innerHTML = '<span class="spinner"></span> Generating...';
            try {
                const form = new FormData();
                form.append('file', selectedFile);
                const format = formatSelect.value;
                const size = sizeSelect.value;
                const url = `/upload?format=${encodeURIComponent(format)}&size=${encodeURIComponent(size)}`;
                const start = performance.now();
                const resp = await fetch(url, { method: 'POST', body: form });
                const end = performance.now();
                if (!resp.ok) {
                    throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
                }
                const blob = await resp.blob();
                const duration = end - start;
                // Get thumbnail dimensions
                const thumbURL = URL.createObjectURL(blob);
                const thumbImg = new window.Image();
                thumbImg.onload = function() {
                    loadingContainer.innerHTML = `
                        <h3>Thumbnail (${(blob.size / 1024).toFixed(1)} KB)</h3>
                        <img src="${thumbURL}" alt="Thumbnail preview"><br>
                        <div class="meta">${blob.type || 'Unknown type'}<br>${thumbImg.naturalWidth}×${thumbImg.naturalHeight} px</div>
                        <a class="download-btn" href="${thumbURL}" download="thumbnail.${format}">Download</a>
                    `;
                    // Show stats
                    stats.style.display = 'block';
                    stats.innerHTML = `
                        <strong>Performance Metrics:</strong><br>
                        Total round-trip time: ${duration.toFixed(1)} ms<br>
                        Thumbnail size: ${(blob.size / 1024).toFixed(1)} KB<br>
                        Compression ratio: ${(selectedFile.size / blob.size).toFixed(1)}:1
                    `;
                    // Show success message
                    successDiv.style.display = 'block';
                    successDiv.textContent = 'Thumbnail generated successfully!';
                    // Auto-scroll to results
                    setTimeout(() => {
                        output.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    }, 100);
                };
                thumbImg.src = thumbURL;
            } catch (error) {
                loadingContainer.innerHTML = '';
                errorDiv.style.display = 'block';
                errorDiv.textContent = `Error processing image: ${error.message}`;
            } finally {
                generateBtn.disabled = false;
                generateBtn.innerHTML = 'Generate Thumbnail';
            }
        });
        // Enable button if file is selected
        updateButtonState();
        // Spinner animation (for browsers that don't support @keyframes in style tag)
        const style = document.createElement('style');
        style.innerHTML = `@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }`;
        document.head.appendChild(style);
        // Accessibility: focus drop area on page load
        window.onload = () => { drop.focus(); };
    </script>
</body>
</html>
        )";
    }
    
    return "";
} 