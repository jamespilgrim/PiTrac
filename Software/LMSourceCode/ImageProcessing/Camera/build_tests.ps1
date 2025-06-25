# Simple Camera Test Build Script for Windows
# Builds and runs Camera bounded context tests using CMake and Boost

Write-Host "Camera Bounded Context Tests" -ForegroundColor Green
Write-Host "============================" -ForegroundColor Green

$CameraDir = Get-Location
$BuildDir = "$CameraDir\build"

# Check if we're in the Camera directory
if (!(Test-Path "domain\camera_domain.hpp")) {
    Write-Host "Error: Run this script from the Camera directory" -ForegroundColor Red
    exit 1
}

# Create and clean build directory
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Path $BuildDir | Out-Null

# Build and test
Push-Location $BuildDir

Write-Host "Configuring..." -ForegroundColor Cyan
& cmake .. | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "CMake failed. Try: cmake .. -DBOOST_DIR=C:\path\to\boost" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "Building..." -ForegroundColor Cyan
& cmake --build . | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "Running tests..." -ForegroundColor Cyan

# Find and run the test executable
$testExe = @(
    ".\tests\Debug\camera_tests.exe",
    ".\tests\camera_tests.exe", 
    ".\Debug\camera_tests.exe",
    ".\camera_tests.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (!$testExe) {
    Write-Host "Test executable not found!" -ForegroundColor Red
    Pop-Location
    exit 1
}

& $testExe
$testResult = $LASTEXITCODE
Pop-Location

if ($testResult -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
} else {
    Write-Host "✗ Tests failed" -ForegroundColor Red
}

exit $testResult
