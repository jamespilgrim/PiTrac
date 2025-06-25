cmake_minimum_required(VERSION 3.10)

# Camera Bounded Context
project(camera_context)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Header-only library for camera abstractions
add_library(camera_abstractions INTERFACE)

# Include directories for the bounded context
target_include_directories(camera_abstractions INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Platform-specific compile definitions
if(UNIX)
    target_compile_definitions(camera_abstractions INTERFACE CAMERA_UNIX_PLATFORM)
elseif(WIN32)
    target_compile_definitions(camera_abstractions INTERFACE CAMERA_WINDOWS_PLATFORM)
endif()

# Enable testing
option(BUILD_CAMERA_TESTS "Build Camera bounded context unit tests" ON)
if(BUILD_CAMERA_TESTS)
    add_subdirectory(tests)
endif()
