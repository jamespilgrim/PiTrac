# PiTrac Windows Development Environment Setup
# Master script to configure OpenCV and Boost environment variables

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PiTrac Development Environment Setup    " -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "This script will help you configure the required environment variables for PiTrac development:" -ForegroundColor White
Write-Host "  - OPENCV_DIR (OpenCV installation path)" -ForegroundColor Gray
Write-Host "  - BOOST_DIR (Boost installation path)" -ForegroundColor Gray
Write-Host ""

# Check current environment state
Write-Host "Current environment status:" -ForegroundColor Yellow

# Function to validate OpenCV installation
function Test-OpenCVInstallation {
    param($path)
    if (-not $path) { return $false }
    if (-not (Test-Path $path)) { return $false }
    
    # Check if the path already points to the build directory
    if ($path.EndsWith('\build')) {
        $buildPath = $path
        $rootPath = Split-Path $path -Parent
    } else {
        $buildPath = Join-Path $path "build"
        $rootPath = $path
    }
    
    $libPath = Join-Path $buildPath "x64\vc16\lib"
    $includePath = Join-Path $buildPath "include"
    
    if (-not (Test-Path $buildPath)) { return $false }
    if (-not (Test-Path $libPath)) { return $false }
    if (-not (Test-Path $includePath)) { return $false }
    
    # Check for OpenCV library files
    $opencvLibs = Get-ChildItem -Path $libPath -Name "opencv_world*.lib" -ErrorAction SilentlyContinue
    return $opencvLibs.Count -gt 0
}

# Function to validate Boost installation
function Test-BoostInstallation {
    param($path)
    if (-not $path) { return $false }
    if (-not (Test-Path $path)) { return $false }
    
    $boostHeaderPath = Join-Path $path "boost"
    $libPath64 = Join-Path $path "lib64-msvc-14.3"
    $stageLibPath = Join-Path $path "stage\lib"
    
    if (-not (Test-Path $boostHeaderPath)) { return $false }
    
    # Check for either library directory
    return (Test-Path $libPath64) -or (Test-Path $stageLibPath)
}

$opencvSet = [bool]$env:OPENCV_DIR
$opencvValid = Test-OpenCVInstallation $env:OPENCV_DIR

$boostSet = [bool]$env:BOOST_DIR
$boostValid = Test-BoostInstallation $env:BOOST_DIR

if ($opencvSet -and $opencvValid) {
    Write-Host "  ✓ OPENCV_DIR = $env:OPENCV_DIR (Valid installation)" -ForegroundColor Green
} elseif ($opencvSet) {
    Write-Host "  ⚠ OPENCV_DIR = $env:OPENCV_DIR (Invalid installation)" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ OPENCV_DIR = (not set)" -ForegroundColor Red
}

if ($boostSet -and $boostValid) {
    Write-Host "  ✓ BOOST_DIR = $env:BOOST_DIR (Valid installation)" -ForegroundColor Green
} elseif ($boostSet) {
    Write-Host "  ⚠ BOOST_DIR = $env:BOOST_DIR (Invalid installation)" -ForegroundColor Yellow
} else {
    Write-Host "  ✗ BOOST_DIR = (not set)" -ForegroundColor Red
}

Write-Host ""

# Determine what needs to be configured
$needsOpenCV = -not ($opencvSet -and $opencvValid)
$needsBoost = -not ($boostSet -and $boostValid)

if ($opencvSet -and $opencvValid -and $boostSet -and $boostValid) {
    Write-Host "Both environment variables are already set and valid!" -ForegroundColor Green
    Write-Host ""
    $reconfigure = Read-Host "Do you want to reconfigure them? (y/N)"
    if ($reconfigure -notmatch "^[Yy]") {
        Write-Host "Setup skipped. Environment is already configured." -ForegroundColor Yellow
        exit 0
    }
    $needsOpenCV = $true
    $needsBoost = $true
} elseif ($opencvSet -and $opencvValid) {
    Write-Host "OpenCV is already properly configured!" -ForegroundColor Green
    if ($boostSet -and -not $boostValid) {
        Write-Host "Boost environment variable is set but installation appears invalid." -ForegroundColor Yellow
    }
} elseif ($boostSet -and $boostValid) {
    Write-Host "Boost is already properly configured!" -ForegroundColor Green
    if ($opencvSet -and -not $opencvValid) {
        Write-Host "OpenCV environment variable is set but installation appears invalid." -ForegroundColor Yellow
    }
}

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Configure OpenCV
if ($needsOpenCV) {
    Write-Host "=== Step 1: Configure OpenCV ===" -ForegroundColor Cyan
    $opencvScript = Join-Path $scriptDir "setup-opencv.ps1"
    
    if (Test-Path $opencvScript) {
        & $opencvScript
        if ($LASTEXITCODE -ne 0) {
            Write-Host "OpenCV setup failed. Exiting." -ForegroundColor Red
            exit 1
        }
        # Refresh environment variable
        $env:OPENCV_DIR = [System.Environment]::GetEnvironmentVariable("OPENCV_DIR", "User")
    } else {
        Write-Host "ERROR: setup-opencv.ps1 not found in $scriptDir" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Configure Boost
if ($needsBoost) {
    Write-Host "=== Step 2: Configure Boost ===" -ForegroundColor Cyan
    $boostScript = Join-Path $scriptDir "setup-boost.ps1"
    
    if (Test-Path $boostScript) {
        & $boostScript
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Boost setup failed. Exiting." -ForegroundColor Red
            exit 1
        }
        # Refresh environment variable
        $env:BOOST_DIR = [System.Environment]::GetEnvironmentVariable("BOOST_DIR", "User")
    } else {
        Write-Host "ERROR: setup-boost.ps1 not found in $scriptDir" -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

# Final verification
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Final environment configuration:" -ForegroundColor Yellow
Write-Host "  OPENCV_DIR = $env:OPENCV_DIR" -ForegroundColor Gray
Write-Host "  BOOST_DIR  = $env:BOOST_DIR" -ForegroundColor Gray
Write-Host ""

# Provide next steps
Write-Host "=== Next Steps ===" -ForegroundColor Green
Write-Host "1. Restart Visual Studio (if currently running)" -ForegroundColor White
Write-Host "2. Open the PiTrac solution file:" -ForegroundColor White
Write-Host "   ..\..\GolfSim.sln" -ForegroundColor Gray
Write-Host "3. Select Debug|x64 configuration" -ForegroundColor White
Write-Host "4. Build the ImageProcessing project" -ForegroundColor White
Write-Host ""

# Offer to open Visual Studio
$openVS = Read-Host "Would you like to open Visual Studio now? (y/N)"
if ($openVS -match "^[Yy]") {
    $solutionPath = Join-Path (Split-Path -Parent $scriptDir) "GolfSim.sln"
    if (Test-Path $solutionPath) {
        Write-Host "Opening Visual Studio..." -ForegroundColor Green
        Start-Process $solutionPath
    } else {
        Write-Host "Solution file not found at expected location: $solutionPath" -ForegroundColor Yellow
        Write-Host "Please navigate to the solution file manually." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Environment setup completed successfully!" -ForegroundColor Green
Write-Host "Thank you for using PiTrac!" -ForegroundColor Cyan
