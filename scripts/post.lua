-- wrk load testing script for ThumbnailGen
-- Usage: wrk -t4 -c50 -d30s -s scripts/post.lua http://localhost:8080/upload

-- Load a test image into memory
local test_image = io.open("test_image.jpg", "rb")
if not test_image then
    print("Error: test_image.jpg not found. Please create a test image first.")
    os.exit(1)
end

local image_data = test_image:read("*all")
test_image:close()

-- Create multipart boundary
local boundary = "----WebKitFormBoundary" .. math.random(1000000, 9999999)

-- Build multipart form data
local multipart_data = "--" .. boundary .. "\r\n"
multipart_data = multipart_data .. "Content-Disposition: form-data; name=\"file\"; filename=\"test.jpg\"\r\n"
multipart_data = multipart_data .. "Content-Type: image/jpeg\r\n\r\n"
multipart_data = multipart_data .. image_data .. "\r\n"
multipart_data = multipart_data .. "--" .. boundary .. "--\r\n"

-- Set request headers
wrk.method = "POST"
wrk.headers["Content-Type"] = "multipart/form-data; boundary=" .. boundary
wrk.headers["Content-Length"] = #multipart_data
wrk.body = multipart_data

-- Response handling
function response(status, headers, body)
    if status ~= 200 then
        print("Error: HTTP " .. status)
    end
end

-- Setup function (called once before the test starts)
function setup()
    print("Starting load test with " .. #image_data .. " bytes test image")
end

-- Teardown function (called once after the test ends)
function done(summary, latency, requests)
    print("Load test completed:")
    print("  Total requests: " .. summary.requests)
    print("  Successful: " .. summary.requests - summary.errors)
    print("  Failed: " .. summary.errors)
    print("  Requests/sec: " .. summary.requests / (summary.duration / 1000000))
    print("  Latency (ms):")
    print("    p50: " .. latency:percentile(50) / 1000)
    print("    p95: " .. latency:percentile(95) / 1000)
    print("    p99: " .. latency:percentile(99) / 1000)
    print("    max: " .. latency.max / 1000)
end 