#pragma once

#include <boost/beast.hpp>
#include <boost/asio.hpp>
#include <memory>
#include <thread>
#include <atomic>
#include "thumbnail_processor.hpp"
#include "metrics.hpp"

namespace beast = boost::beast;
namespace http = beast::http;
namespace net = boost::asio;
using tcp = boost::asio::ip::tcp;

class ThumbnailServer {
public:
    ThumbnailServer(int port, int thread_count);
    ~ThumbnailServer();

    void run();
    void stop();

private:
    void do_accept();
    void handle_session(tcp::socket socket);
    void handle_request(http::request<http::dynamic_body>& req, 
                       http::response<http::vector_body<uint8_t>>& res);
    void handle_upload(const http::request<http::dynamic_body>& req,
                      http::response<http::vector_body<uint8_t>>& res,
                      const std::string& format,
                      int target_width,
                      int target_height);
    void handle_metrics(http::response<http::string_body>& res);
    void handle_static(const std::string& path, http::response<http::string_body>& res);
    std::string get_static_content(const std::string& path);

    int port_;
    int thread_count_;
    net::io_context ioc_;
    std::unique_ptr<tcp::acceptor> acceptor_;
    std::vector<std::thread> threads_;
    std::atomic<bool> running_{false};
    
    ThumbnailProcessor processor_;
    MetricsCollector metrics_;
}; 