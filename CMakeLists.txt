cmake_minimum_required(VERSION 3.16)
project(ThumbnailGen VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Boost REQUIRED COMPONENTS system filesystem)
find_package(PkgConfig REQUIRED)
pkg_check_modules(VIPS REQUIRED vips)

# Include directories
include_directories(${VIPS_INCLUDE_DIRS})

# Create executable
add_executable(thumbnail_service
    src/main.cpp
    src/server.cpp
    src/thumbnail_processor.cpp
    src/metrics.cpp
)

# Link libraries - use pkg-config to get all required libraries
target_link_libraries(thumbnail_service
    ${Boost_LIBRARIES}
    ${VIPS_LIBRARIES}
    pthread
    dl
    m
)

# Compiler flags
target_compile_options(thumbnail_service PRIVATE
    ${VIPS_CFLAGS_OTHER}
    -O3
    -march=native
    -DNDEBUG
)

# Install target
install(TARGETS thumbnail_service DESTINATION bin) 