
# PiTrac Windows Development Setup

This document provides instructions for setting up the PiTrac development environment on Windows for debugging and development purposes.

## Quick Setup (Recommended)

**For automated setup, run the PowerShell script:**

```powershell
# Navigate to the windows-setup directory
cd "c:\kata\PiTrac\Software\LMSourceCode\ImageProcessing\windows-setup"

# Run the automated setup script
.\setup-environment.ps1
```

This script will:
- Prompt you for OpenCV and Boost installation paths
- Validate the installations
- Set the required environment variables
- Provide guidance for next steps

## Manual Setup

If you prefer to set up the environment manually, follow the instructions below.

## Prerequisites

1. **Visual Studio 2022** (Community, Professional, or Enterprise)
2. **OpenCV 4.10.0**
3. **Boost 1.87.0**

## Environment Variables

The PiTrac Visual Studio project uses environment variables to locate dependencies. You must set these environment variables before opening Visual Studio:

### Required Environment Variables

- **`OPENCV_DIR`** - Path to your OpenCV installation root directory
- **`BOOST_DIR`** - Path to your Boost installation root directory

### Setting Environment Variables

#### Option 1: System Environment Variables (Recommended)
1. Open **System Properties** → **Advanced** → **Environment Variables**
2. Under **System Variables**, click **New** and add:
   ```   Variable name: OPENCV_DIR
   Variable value: C:\tools\opencv
   ```
3. Add another variable:
   ```
   Variable name: BOOST_DIR
   Variable value: C:\Dev_Libs\boost
   ```
4. **Restart Visual Studio** after setting these variables

#### Option 2: User Environment Variables
Follow the same steps but add the variables under **User Variables** instead of **System Variables**.

#### Option 3: PowerShell Session (Temporary)
```powershell
$env:OPENCV_DIR = "C:\tools\opencv"
$env:BOOST_DIR = "C:\Dev_Libs\boost"
# Launch Visual Studio from this PowerShell session
& "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe"
```

## Installation Instructions

### 1. Install OpenCV 4.11.0

1. Download OpenCV 4.11.0 from [opencv.org](https://opencv.org/releases/)
2. Extract to `C:\tools\opencv` (or your preferred location)
3. Set `OPENCV_DIR` environment variable to point to this location

**Expected directory structure:**
```
C:\tools\opencv\
├── build\
│   ├── include\
│   │   └── opencv2\
│   └── x64\
│       └── vc16\
│           ├── bin\
│           └── lib\
└── sources\
```

### 2. Install Boost 1.87.0

#### Option A: Pre-built Binaries (Recommended)
1. Download pre-built Boost binaries from [SourceForge](https://sourceforge.net/projects/boost/files/boost-binaries/)
2. Choose: `boost_1_87_0-msvc-14.3-64.exe`
3. Install to `C:\Dev_Libs\boost` (or your preferred location)
4. Set `BOOST_DIR` environment variable to point to this location

#### Option B: Build from Source
1. Download Boost 1.87.0 source from [boost.org](https://www.boost.org/)
2. Build using the Visual Studio toolchain
3. Set `BOOST_DIR` to your build output directory

**Expected directory structure:**
```
C:\Dev_Libs\boost\
├── boost\
├── lib64-msvc-14.3\
└── stage\
```

## Project Configuration

The Visual Studio project file (`ImageProcessing.vcxproj.user`) is configured to use these environment variables:

```xml
<LocalDebuggerEnvironment>
PITRAC_BASE_IMAGE_LOGGING_DIR=$(ProjectDir)
PATH=%PATH%;$(OPENCV_DIR)\build\x64\vc16\bin;$(BOOST_DIR)\lib64-msvc-14.3
</LocalDebuggerEnvironment>
```

## Verification

To verify your setup:

1. Open Visual Studio
2. Load the `GolfSim.sln` solution
3. Check **Project Properties** → **C/C++** → **Additional Include Directories**
4. Verify the paths resolve correctly (no red error indicators)
5. Build the project in Debug configuration

## Troubleshooting

### Automation Scripts

This directory includes PowerShell scripts to automate environment setup:

- **`setup-environment.ps1`** - Master setup script (runs both OpenCV and Boost setup)
- **`setup-opencv.ps1`** - OpenCV-specific environment setup
- **`setup-boost.ps1`** - Boost-specific environment setup

To use the scripts:

```powershell
# Full automated setup
.\setup-environment.ps1

# Or run individual scripts
.\setup-opencv.ps1
.\setup-boost.ps1
```

The scripts will:
- Validate installation paths and directory structure
- Check for required library files
- Set environment variables persistently
- Provide detailed feedback and error messages

### Common Issues

**Environment variables not recognized:**
- Restart Visual Studio after setting environment variables
- Verify variables are set at system level, not just user level
- Check for typos in variable names or paths

**OpenCV libraries not found:**
- Ensure you downloaded the Windows pre-built binaries, not source-only
- Verify the `build\x64\vc16` directory exists (Visual Studio 2019/2022 compatibility)

**Boost compilation errors:**
- Ensure you have the correct MSVC version (14.3 for VS 2022)
- Check that `lib64-msvc-14.3` directory exists in your Boost installation

### Getting Help

For additional help, refer to:
- [PiTrac Documentation](../../../Documentation/)
- [OpenCV Windows Installation Guide](https://docs.opencv.org/4.x/d3/d52/tutorial_windows_install.html)
- [Boost Getting Started](https://www.boost.org/doc/libs/1_87_0/more/getting_started/windows.html)