/*
 * Domain interface for Camera bounded context
 * 
 * This file defines the common interface for camera operations,
 * independent of platform implementation.
 * 
 * Step 1 of incremental refactoring: Define domain interface only.
 * No existing files are modified in this step.
 */

#pragma once

namespace golf_sim::camera::domain {
    
    // Domain types that abstract platform-specific implementations
    // These provide a clean interface for the application layer
    
    struct Size {
        unsigned int width, height;
        Size(unsigned int w = 0, unsigned int h = 0) : width(w), height(h) {}
    };

    struct Transform {
        int value = 0;
        Transform(int v = 0) : value(v) {}
    };

    struct PixelFormat {
        unsigned int fourcc = 0;
        PixelFormat(unsigned int f = 0) : fourcc(f) {}
    };

    struct ColorSpace {
        int value = 0;
        ColorSpace(int v = 0) : value(v) {}
    };

} // namespace golf_sim::camera::domain
