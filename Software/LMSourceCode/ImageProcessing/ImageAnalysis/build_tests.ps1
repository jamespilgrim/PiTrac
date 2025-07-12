# Image Analysis BC - Fast Build & Test Script
# Combines speed of Camera script with flexibility of ImageAnalysis script
#
# Usage:
#   .\build_tests.ps1              # Fast build and test
#   .\build_tests.ps1 -Verbose     # Show detailed output
#   .\build_tests.ps1 -SkipTests   # Build only
#
# After test failures, use:
#   .\approve_changes.ps1          # Review and approve changes

param(
    [switch]$Verbose,
    [switch]$SkipTests
)

Write-Host "Image Analysis BC - Build & Test" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

$BuildDir = "build"

# Check and set environment variables for dependencies if not already set
if (-not $env:BOOST_ROOT) {
    $DefaultBoostPath = "C:\Dev_Libs\boost"
    Write-Host "BOOST_ROOT environment variable not set. Using default: $DefaultBoostPath" -ForegroundColor Yellow
    $env:BOOST_ROOT = $DefaultBoostPath
} else {
    Write-Host "Using BOOST_ROOT: $env:BOOST_ROOT" -ForegroundColor Green
}

if (-not $env:OPENCV_DIR) {
    $DefaultOpenCVPath = "C:\opencv"
    Write-Host "OPENCV_DIR environment variable not set. Using default: $DefaultOpenCVPath" -ForegroundColor Yellow
    $env:OPENCV_DIR = $DefaultOpenCVPath
} else {
    Write-Host "Using OPENCV_DIR: $env:OPENCV_DIR" -ForegroundColor Green
}

# Check required files
if (!(Test-Path "domain\value_objects.hpp") -or !(Test-Path "CMakeLists.txt")) {
    Write-Host "ERROR: Run this script from the ImageAnalysis directory" -ForegroundColor Red
    exit 1
}

Write-Host "Found required files" -ForegroundColor Green

# Always clean build for speed and reliability (like Camera script)
if (Test-Path $BuildDir) {
    Write-Host "Cleaning..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Path $BuildDir | Out-Null

Push-Location $BuildDir

# Configure
Write-Host "Configuring..." -ForegroundColor Cyan

# Check if $env:OPENCV_DIR ends with 'build' - if not, append it
if (-not $env:OPENCV_DIR.EndsWith("build")) {
    $OpenCVConfigPath = Join-Path $env:OPENCV_DIR "build"
    if (Test-Path "$OpenCVConfigPath") {
        Write-Host "Using OpenCV config path: $OpenCVConfigPath" -ForegroundColor Cyan
    } else {
        Write-Host "Warning: $OpenCVConfigPath not found. Using $env:OPENCV_DIR directly." -ForegroundColor Yellow
        $OpenCVConfigPath = $env:OPENCV_DIR
    }
} else {
    $OpenCVConfigPath = $env:OPENCV_DIR
}

if ($Verbose) {
    & cmake .. -G "Visual Studio 17 2022" -A x64 -DOPENCV_DIR="$OpenCVConfigPath"
} else {
    & cmake .. -G "Visual Studio 17 2022" -A x64 -DOPENCV_DIR="$OpenCVConfigPath" | Out-Null
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: CMake failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Build (always Release for speed)
Write-Host "Building..." -ForegroundColor Cyan

if ($Verbose) {
    & cmake --build . --config Release
} else {
    & cmake --build . --config Release | Out-Null
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build failed" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "Build successful!" -ForegroundColor Green

# Run tests unless skipped
if ($SkipTests) {
    Write-Host "Skipping tests" -ForegroundColor Yellow
} else {
    Write-Host "Running tests..." -ForegroundColor Cyan
    
    if ($Verbose) {
        & ctest -C Release --verbose
    } else {
        & ctest -C Release
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "All tests passed!" -ForegroundColor Green
        Write-Host "Ready for production!" -ForegroundColor Green
    } else {
        Write-Host "Tests failed" -ForegroundColor Red
        Write-Host "Try: .\build_tests.ps1 -Verbose" -ForegroundColor Yellow
        Pop-Location
        exit 1
    }
}

Pop-Location

# Quick artifact summary (simplified)
if (Test-Path "build\Release") {
    $exeCount = (Get-ChildItem "build\Release" -Filter "*.exe").Count
    $libCount = (Get-ChildItem "build\Release" -Filter "*.lib").Count
    Write-Host "Built: $exeCount tests, $libCount libraries" -ForegroundColor Cyan
}

# Clean up approval testing artifacts
if (Test-Path "tests\approval_artifacts") {
    $receivedFiles = Get-ChildItem "tests\approval_artifacts" -Filter "*.received.*" -ErrorAction SilentlyContinue
    if ($receivedFiles.Count -gt 0) {
        Write-Host "Cleaning up $($receivedFiles.Count) approval test artifacts..." -ForegroundColor Yellow
        $receivedFiles | Remove-Item -Force
        if ($Verbose) {
            Write-Host "Removed: $($receivedFiles.Name -join ', ')" -ForegroundColor Gray
        }
    }
}

Write-Host "Done!" -ForegroundColor Green
