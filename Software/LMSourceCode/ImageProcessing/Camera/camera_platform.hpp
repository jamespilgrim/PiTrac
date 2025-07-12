/*
 * Camera Platform Selector
 * 
 * This header automatically includes the appropriate camera implementation
 * based on the target platform. Use this single include throughout the
 * codebase instead of platform-specific headers.
 *  * Example usage:
 *   #include "Camera/camera_platform.hpp"
 *   // Now you can use golf_sim::camera::domain types and platform-specific implementations
 */

#pragma once

// Always include the domain interface first
#include "domain/camera_domain.hpp"

// Include platform-specific implementation
#ifdef __unix__
    #include "infrastructure/unix/libcamera_unix_impl.hpp"
#elif defined(_WIN32) || defined(WIN32)
    // Windows implementation will be added here
    // #include "infrastructure/windows/libcamera_windows_impl.hpp"
#else
    #error "Unsupported platform for camera operations"
#endif
