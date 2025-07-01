#pragma once

#include <vector>
#include <cstdint>

class ThumbnailProcessor {
public:
    ThumbnailProcessor();
    ~ThumbnailProcessor();

    // Create a thumbnail from image data
    std::vector<uint8_t> create_thumbnail(const std::vector<uint8_t>& image_data, 
                                         int target_width, 
                                         int target_height);

private:
    // Helper method to convert vips image to PNG buffer
    std::vector<uint8_t> image_to_png_buffer(void* vips_image);
}; 