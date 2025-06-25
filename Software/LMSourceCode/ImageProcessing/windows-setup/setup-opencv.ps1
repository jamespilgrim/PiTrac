# PiTrac OpenCV Environment Setup Script
# This script helps set up the OPENCV_DIR environment variable for PiTrac development

Write-Host "=== PiTrac OpenCV Environment Setup ===" -ForegroundColor Green
Write-Host ""

# Prompt for OpenCV path
Write-Host "Please enter the path to your OpenCV installation:" -ForegroundColor Yellow
Write-Host "Example: E:\Dev_Libs\opencv" -ForegroundColor Gray
Write-Host ""
$opencvPath = Read-Host "OpenCV Path"

# Trim whitespace and remove quotes if present
$opencvPath = $opencvPath.Trim().Trim('"').Trim("'")

# Test if the path exists
if (-not (Test-Path $opencvPath)) {
    Write-Host "ERROR: Path '$opencvPath' does not exist!" -ForegroundColor Red
    Write-Host "Please verify the path and try again." -ForegroundColor Red
    exit 1
}

# Test for expected OpenCV directory structure
$buildPath = Join-Path $opencvPath "build"
$includePath = Join-Path $buildPath "include"
$libPath = Join-Path $buildPath "x64\vc16\lib"
$binPath = Join-Path $buildPath "x64\vc16\bin"

Write-Host "Validating OpenCV installation structure..." -ForegroundColor Yellow

$validationErrors = @()

if (-not (Test-Path $buildPath)) {
    $validationErrors += "Missing 'build' directory"
}

if (-not (Test-Path $includePath)) {
    $validationErrors += "Missing 'build\include' directory"
}

if (-not (Test-Path $libPath)) {
    $validationErrors += "Missing 'build\x64\vc16\lib' directory"
}

if (-not (Test-Path $binPath)) {
    $validationErrors += "Missing 'build\x64\vc16\bin' directory"
}

# Check for OpenCV library files
if (Test-Path $libPath) {
    $opencvLibs = Get-ChildItem -Path $libPath -Name "opencv_world*.lib" | Sort-Object
    if ($opencvLibs.Count -eq 0) {
        $validationErrors += "No OpenCV library files found in lib directory"
    } else {
        Write-Host "Found OpenCV libraries:" -ForegroundColor Green
        foreach ($lib in $opencvLibs) {
            Write-Host "  - $lib" -ForegroundColor Gray
        }
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: OpenCV installation validation failed:" -ForegroundColor Yellow
    foreach ($error in $validationErrors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "This may cause build issues. Expected structure:" -ForegroundColor Yellow
    Write-Host "  $opencvPath\" -ForegroundColor Gray
    Write-Host "  ├── build\" -ForegroundColor Gray
    Write-Host "  │   ├── include\" -ForegroundColor Gray
    Write-Host "  │   └── x64\" -ForegroundColor Gray
    Write-Host "  │       └── vc16\" -ForegroundColor Gray
    Write-Host "  │           ├── bin\" -ForegroundColor Gray
    Write-Host "  │           └── lib\" -ForegroundColor Gray
    Write-Host ""
    
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -notmatch "^[Yy]") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 1
    }
}

# Set the environment variable to the build directory
Write-Host ""
Write-Host "Setting OPENCV_DIR environment variable..." -ForegroundColor Yellow

try {
    # Point to the build directory for correct path resolution
    $opencvBuildPath = Join-Path $opencvPath "build"
    
    # Set for current session
    $env:OPENCV_DIR = $opencvBuildPath
    
    # Set permanently for current user
    [System.Environment]::SetEnvironmentVariable("OPENCV_DIR", $opencvBuildPath, "User")    
    Write-Host "SUCCESS: OPENCV_DIR set to '$opencvBuildPath'" -ForegroundColor Green
    
    # Verify the setting
    $currentValue = [System.Environment]::GetEnvironmentVariable("OPENCV_DIR", "User")
    if ($currentValue -eq $opencvBuildPath) {
        Write-Host "Environment variable verified successfully." -ForegroundColor Green
    } else {
        Write-Host "WARNING: Environment variable verification failed." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "ERROR: Failed to set environment variable: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Green
Write-Host "1. Restart Visual Studio (if already running)" -ForegroundColor White
Write-Host "2. Run setup-boost.ps1 to configure Boost environment" -ForegroundColor White
Write-Host "3. Open GolfSim.sln in Visual Studio" -ForegroundColor White
Write-Host "4. Build the project to verify configuration" -ForegroundColor White
Write-Host ""
Write-Host "Current environment variables:" -ForegroundColor Yellow
Write-Host "  OPENCV_DIR = $env:OPENCV_DIR" -ForegroundColor Gray
if ($env:BOOST_DIR) {
    Write-Host "  BOOST_DIR  = $env:BOOST_DIR" -ForegroundColor Gray
} else {
    Write-Host "  BOOST_DIR  = (not set - run setup-boost.ps1)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Setup completed successfully!" -ForegroundColor Green
