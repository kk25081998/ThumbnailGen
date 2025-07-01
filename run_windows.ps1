# ThumbnailGen Windows PowerShell Launcher
# Run this script in PowerShell

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    ThumbnailGen - Windows Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
try {
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Docker found: $dockerVersion" -ForegroundColor Green
    } else {
        throw "Docker not found"
    }
} catch {
    Write-Host "✗ ERROR: Docker is not installed or not running." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker Desktop from:" -ForegroundColor Yellow
    Write-Host "https://www.docker.com/products/docker-desktop/" -ForegroundColor Blue
    Write-Host ""
    Write-Host "After installation:" -ForegroundColor Yellow
    Write-Host "1. Restart your computer" -ForegroundColor White
    Write-Host "2. Start Docker Desktop" -ForegroundColor White
    Write-Host "3. Run this script again" -ForegroundColor White
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Building ThumbnailGen Docker image..." -ForegroundColor Yellow

# Build the Docker image
try {
    docker build -t thumbnailgen .
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Build successful!" -ForegroundColor Green
    } else {
        throw "Build failed"
    }
} catch {
    Write-Host "✗ ERROR: Failed to build Docker image." -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Starting ThumbnailGen service..." -ForegroundColor Yellow
Write-Host ""
Write-Host "The service will be available at: http://localhost:8080" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop the service" -ForegroundColor Yellow
Write-Host ""

# Run the service
try {
    docker run -p 8080:8080 thumbnailgen
} catch {
    Write-Host "Service stopped." -ForegroundColor Yellow
}

Read-Host "Press Enter to exit" 