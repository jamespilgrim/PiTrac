# PiTrac Boost Environment Setup Script
# This script helps set up the BOOST_DIR environment variable for PiTrac development

Write-Host "=== PiTrac Boost Environment Setup ===" -ForegroundColor Green
Write-Host ""

# Prompt for Boost path
Write-Host "Please enter the path to your Boost installation:" -ForegroundColor Yellow
Write-Host "Example: E:\Dev_Libs\boost" -ForegroundColor Gray
Write-Host ""
$boostPath = Read-Host "Boost Path"

# Trim whitespace and remove quotes if present
$boostPath = $boostPath.Trim().Trim('"').Trim("'")

# Test if the path exists
if (-not (Test-Path $boostPath)) {
    Write-Host "ERROR: Path '$boostPath' does not exist!" -ForegroundColor Red
    Write-Host "Please verify the path and try again." -ForegroundColor Red
    exit 1
}

# Test for expected Boost directory structure
$boostHeaderPath = Join-Path $boostPath "boost"
$libPath = Join-Path $boostPath "lib64-msvc-14.3"
$stageLibPath = Join-Path $boostPath "stage\lib"

Write-Host "Validating Boost installation structure..." -ForegroundColor Yellow

$validationErrors = @()

if (-not (Test-Path $boostHeaderPath)) {
    $validationErrors += "Missing 'boost' header directory"
}

# Check for library directories (either lib64-msvc-14.3 or stage\lib)
$hasLib64 = Test-Path $libPath
$hasStageLib = Test-Path $stageLibPath

if (-not $hasLib64 -and -not $hasStageLib) {
    $validationErrors += "Missing library directory (expected 'lib64-msvc-14.3' or 'stage\lib')"
} else {
    if ($hasLib64) {
        Write-Host "Found Boost library directory: lib64-msvc-14.3" -ForegroundColor Green
        $libFiles = Get-ChildItem -Path $libPath -Name "*.lib" | Select-Object -First 5
        if ($libFiles.Count -gt 0) {
            Write-Host "Sample library files:" -ForegroundColor Green
            foreach ($lib in $libFiles) {
                Write-Host "  - $lib" -ForegroundColor Gray
            }
            if ((Get-ChildItem -Path $libPath -Name "*.lib").Count -gt 5) {
                Write-Host "  ... and more" -ForegroundColor Gray
            }
        }
    }
    
    if ($hasStageLib) {
        Write-Host "Found Boost library directory: stage\lib" -ForegroundColor Green
        $libFiles = Get-ChildItem -Path $stageLibPath -Name "*.lib" | Select-Object -First 5
        if ($libFiles.Count -gt 0) {
            Write-Host "Sample library files:" -ForegroundColor Green
            foreach ($lib in $libFiles) {
                Write-Host "  - $lib" -ForegroundColor Gray
            }
            if ((Get-ChildItem -Path $stageLibPath -Name "*.lib").Count -gt 5) {
                Write-Host "  ... and more" -ForegroundColor Gray
            }
        }
    }
}

# Check for version.hpp to identify Boost version
$versionFile = Join-Path $boostHeaderPath "version.hpp"
if (Test-Path $versionFile) {
    try {
        $versionContent = Get-Content $versionFile | Select-String "BOOST_VERSION" | Select-Object -First 1
        if ($versionContent) {
            Write-Host "Boost version file found: $versionContent" -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not read Boost version information" -ForegroundColor Yellow
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "WARNING: Boost installation validation failed:" -ForegroundColor Yellow
    foreach ($error in $validationErrors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "This may cause build issues. Expected structure:" -ForegroundColor Yellow
    Write-Host "  $boostPath\" -ForegroundColor Gray
    Write-Host "  ├── boost\" -ForegroundColor Gray
    Write-Host "  ├── lib64-msvc-14.3\    (for pre-built binaries)" -ForegroundColor Gray
    Write-Host "  └── stage\"  -ForegroundColor Gray
    Write-Host "      └── lib\             (for source builds)" -ForegroundColor Gray
    Write-Host ""
    
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -notmatch "^[Yy]") {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 1
    }
}

# Set the environment variable
Write-Host ""
Write-Host "Setting BOOST_DIR environment variable..." -ForegroundColor Yellow

try {
    # Set for current session
    $env:BOOST_DIR = $boostPath
    
    # Set permanently for current user
    [System.Environment]::SetEnvironmentVariable("BOOST_DIR", $boostPath, "User")
    
    Write-Host "SUCCESS: BOOST_DIR set to '$boostPath'" -ForegroundColor Green
    
    # Verify the setting
    $currentValue = [System.Environment]::GetEnvironmentVariable("BOOST_DIR", "User")
    if ($currentValue -eq $boostPath) {
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
Write-Host "2. Open GolfSim.sln in Visual Studio" -ForegroundColor White
Write-Host "3. Build the project to verify configuration" -ForegroundColor White
Write-Host ""
Write-Host "Current environment variables:" -ForegroundColor Yellow
if ($env:OPENCV_DIR) {
    Write-Host "  OPENCV_DIR = $env:OPENCV_DIR" -ForegroundColor Gray
} else {
    Write-Host "  OPENCV_DIR = (not set - run setup-opencv.ps1)" -ForegroundColor Red
}
Write-Host "  BOOST_DIR  = $env:BOOST_DIR" -ForegroundColor Gray

Write-Host ""
Write-Host "Setup completed successfully!" -ForegroundColor Green
