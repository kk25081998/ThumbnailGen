#include "thumbnail_processor.hpp"
#include <iostream>
#include <stdexcept>
#include <vips/vips.h>
#include <glib.h>

ThumbnailProcessor::ThumbnailProcessor() {
    std::cout << "Initializing libvips..." << std::endl;
    if (VIPS_INIT("thumbnail_service")) {
        throw std::runtime_error("Failed to initialize libvips");
    }
    vips_concurrency_set(vips_concurrency_get());
    vips_cache_set_max(0);
    std::cout << "libvips initialized." << std::endl;
}

ThumbnailProcessor::~ThumbnailProcessor() {
    std::cout << "Shutting down libvips..." << std::endl;
    vips_shutdown();
    std::cout << "libvips shutdown complete." << std::endl;
}

std::vector<uint8_t> ThumbnailProcessor::create_thumbnail(const std::vector<uint8_t>& image_data, 
                                                         int target_width, 
                                                         int target_height,
                                                         const std::string& format) {
    VipsImage *input = nullptr;
    VipsImage *thumbnail = nullptr;
    void *buffer = nullptr;
    size_t size = 0;
    std::vector<uint8_t> result;

    try {
        std::cout << "Processing image: " << image_data.size() << " bytes" << std::endl;

        std::cout << "Loading image from buffer..." << std::endl;
        input = vips_image_new_from_buffer(
            static_cast<const void*>(image_data.data()), 
            image_data.size(), 
            "", 
            nullptr
        );
        if (!input) {
            std::string err = vips_error_buffer();
            vips_error_clear();
            std::cerr << "Failed to load image: " << err << std::endl;
            throw std::runtime_error("Failed to load image: " + err);
        }
        std::cout << "Loaded image!" << std::endl;

        std::cout << "Creating thumbnail..." << std::endl;
        if (vips_thumbnail_image(input, &thumbnail, target_width, 
                                "height", target_height,
                                "crop", VIPS_INTERESTING_CENTRE,
                                "linear", true,
                                "no_rotate", true,
                                nullptr)) {
            std::string err = vips_error_buffer();
            vips_error_clear();
            g_object_unref(input);
            std::cerr << "Failed to create thumbnail: " << err << std::endl;
            throw std::runtime_error("Failed to create thumbnail: " + err);
        }
        std::cout << "Created thumbnail!" << std::endl;

        std::cout << "Saving " << format << " to buffer..." << std::endl;
        int save_result = 1;
        if (format == "jpeg") {
            save_result = vips_jpegsave_buffer(thumbnail, &buffer, &size,
                                              "Q", 90,
                                              "strip", true,
                                              nullptr);
        } else if (format == "webp") {
            save_result = vips_webpsave_buffer(thumbnail, &buffer, &size,
                                               "Q", 90,
                                               nullptr);
        } else { // default to PNG
            save_result = vips_pngsave_buffer(thumbnail, &buffer, &size,
                                             "compression", 6,
                                             "interlace", false,
                                             "filter", VIPS_FOREIGN_PNG_FILTER_NONE,
                                             nullptr);
        }
        if (save_result) {
            std::string err = vips_error_buffer();
            vips_error_clear();
            g_object_unref(thumbnail);
            g_object_unref(input);
            std::cerr << "Failed to save " << format << ": " << err << std::endl;
            throw std::runtime_error("Failed to save " + format + ": " + err);
        }
        std::cout << "Saved " << format << "!" << std::endl;

        result.assign(static_cast<uint8_t*>(buffer), static_cast<uint8_t*>(buffer) + size);

        g_free(buffer);
        g_object_unref(thumbnail);
        g_object_unref(input);

        std::cout << "Thumbnail processing complete!" << std::endl;
        return result;
    } catch (const std::exception& e) {
        if (buffer) g_free(buffer);
        if (thumbnail) g_object_unref(thumbnail);
        if (input) g_object_unref(input);
        std::cerr << "Thumbnail processing error: " << e.what() << std::endl;
        throw;
    } catch (...) {
        if (buffer) g_free(buffer);
        if (thumbnail) g_object_unref(thumbnail);
        if (input) g_object_unref(input);
        std::cerr << "Unknown thumbnail processing error" << std::endl;
        throw std::runtime_error("Unknown error during image processing");
    }
}

std::vector<uint8_t> ThumbnailProcessor::image_to_png_buffer(void* vips_image) {
    throw std::runtime_error("Not implemented in C API version");
} 