# Multi-stage build for ThumbnailGen
FROM ubuntu:20.04 as builder

# Use a fast mirror and install build dependencies
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirror.math.princeton.edu/pub/ubuntu/|g' /etc/apt/sources.list && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    cmake \
    libboost-all-dev \
    libvips-dev \
    libjpeg-turbo8-dev \
    pkg-config \
    git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Build the application
RUN mkdir build && cd build \
    && cmake .. \
    && make -j$(nproc)

# Runtime stage
FROM ubuntu:20.04

# Use a fast mirror and install runtime dependencies
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirror.math.princeton.edu/pub/ubuntu/|g' /etc/apt/sources.list && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libvips \
    libjpeg-turbo8 \
    libexif12 \
    libtiff5 \
    libpng16-16 \
    libwebp6 \
    libboost-system1.71.0 \
    libboost-filesystem1.71.0 \
    curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 thumbnailgen

# Copy binary from builder stage
COPY --from=builder /app/build/thumbnail_service /usr/local/bin/

# Set ownership
RUN chown thumbnailgen:thumbnailgen /usr/local/bin/thumbnail_service

# Switch to non-root user
USER thumbnailgen

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/metrics || exit 1

# Run the service
CMD ["/usr/local/bin/thumbnail_service", "--port", "8080"] 