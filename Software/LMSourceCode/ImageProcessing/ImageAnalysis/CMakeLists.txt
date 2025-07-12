# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022-2025, Verdant Consultants, LLC.

cmake_minimum_required(VERSION 3.16)
project(ImageAnalysis)

# Handle CMake policy for FindBoost module removal in newer CMake versions
if(POLICY CMP0167)
    cmake_policy(SET CMP0167 OLD)  # Keep old behavior for compatibility
    # TODO: Migrate to new Boost discovery when upgrading CMake
endif()

# Handle CMake policy for BOOST_ROOT variable
if(POLICY CMP0144)
    cmake_policy(SET CMP0144 NEW)
endif()

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set default build type if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
    message(STATUS "Build type not specified, defaulting to Release")
endif()

# Find required packages
# Configure OpenCV detection - require explicit OPENCV_DIR
if(NOT DEFINED ENV{OPENCV_DIR} AND NOT DEFINED OPENCV_DIR)
    message(FATAL_ERROR 
        "OPENCV_DIR must be set. Please set environment variable or pass -DOPENCV_DIR=<path> to CMake.\n"
        "Example: $env:OPENCV_DIR = \"C:/opencv\" (PowerShell)\n"
        "Or: cmake -DOPENCV_DIR=\"C:/opencv\" .."
    )
endif()

# Use environment variable if set, otherwise use CMake variable
if(DEFINED ENV{OPENCV_DIR} AND NOT DEFINED OPENCV_DIR)
    set(OPENCV_DIR $ENV{OPENCV_DIR})
    message(STATUS "Using OPENCV_DIR from environment: ${OPENCV_DIR}")
elseif(DEFINED OPENCV_DIR)
    message(STATUS "Using OPENCV_DIR from CMake: ${OPENCV_DIR}")
endif()

# Validate the path exists
if(NOT EXISTS "${OPENCV_DIR}")
    message(FATAL_ERROR "OPENCV_DIR path does not exist: ${OPENCV_DIR}")
endif()

# Add OpenCV directory to the prefix path so find_package can find it
# The path should point directly to the directory containing OpenCVConfig.cmake
list(APPEND CMAKE_PREFIX_PATH "${OPENCV_DIR}")
message(STATUS "Looking for OpenCVConfig.cmake in: ${OPENCV_DIR}")

find_package(OpenCV REQUIRED)

# Configure Boost detection - require explicit BOOST_ROOT
if(NOT DEFINED ENV{BOOST_ROOT} AND NOT DEFINED BOOST_ROOT)
    message(FATAL_ERROR 
        "BOOST_ROOT must be set. Please set environment variable or pass -DBOOST_ROOT=<path> to CMake.\n"
        "Example: $env:BOOST_ROOT = \"C:/Dev_Libs/boost\" (PowerShell)\n"
        "Or: cmake -DBOOST_ROOT=\"C:/Dev_Libs/boost\" .."
    )
endif()

# Use environment variable if set, otherwise use CMake variable
if(DEFINED ENV{BOOST_ROOT} AND NOT DEFINED BOOST_ROOT)
    set(BOOST_ROOT $ENV{BOOST_ROOT})
    message(STATUS "Using BOOST_ROOT from environment: ${BOOST_ROOT}")
elseif(DEFINED BOOST_ROOT)
    message(STATUS "Using BOOST_ROOT from CMake: ${BOOST_ROOT}")
endif()

# Validate the path exists
if(NOT EXISTS "${BOOST_ROOT}")
    message(FATAL_ERROR "BOOST_ROOT path does not exist: ${BOOST_ROOT}")
endif()

# Configure Boost detection - Traditional FindBoost for compatibility with static libraries
set(Boost_USE_STATIC_LIBS ON)    # Use static libraries (consistent across environments)
set(Boost_USE_MULTITHREADED ON)  # Enable multithreaded libraries
set(Boost_USE_STATIC_RUNTIME OFF) # Don't use static runtime (avoids conflicts)
set(Boost_NO_BOOST_CMAKE ON)     # Use traditional FindBoost module for better static lib support
set(Boost_NO_SYSTEM_PATHS ON)    # Only look in specified paths

# Add Boost library directory to help CMake find the libraries
if(BOOST_ROOT)
    list(APPEND CMAKE_PREFIX_PATH "${BOOST_ROOT}")
    
    # Set additional hints for modern CMake
    set(Boost_ROOT "${BOOST_ROOT}")
    set(BOOST_LIBRARYDIR "${BOOST_ROOT}/lib64-msvc-14.3")
    set(BOOST_INCLUDEDIR "${BOOST_ROOT}/include")
    
    # Fallback if include is in root directory
    if(NOT EXISTS "${BOOST_INCLUDEDIR}")
        set(BOOST_INCLUDEDIR "${BOOST_ROOT}")
    endif()
endif()

# Find Boost with unit test framework
find_package(Boost REQUIRED COMPONENTS unit_test_framework)

# Source files for the bounded context
set(IMAGE_ANALYSIS_SOURCES
    infrastructure/opencv_image_analyzer.cpp
)

set(IMAGE_ANALYSIS_HEADERS
    domain/value_objects.hpp
    domain/analysis_results.hpp
    domain/interfaces.hpp
    application/image_analysis_service.hpp
    infrastructure/opencv_image_analyzer.hpp
    infrastructure/ml_image_analyzer.hpp
)

# Approval testing framework sources
set(APPROVAL_FRAMEWORK_SOURCES
    tests/approval/approval_test_config.cpp
    tests/approval/result_formatter.cpp
    tests/approval/visualization_service.cpp
    tests/approval/comparison_service.cpp
    tests/approval/diff_launcher.cpp
    tests/approval/approval_test_orchestrator.cpp
)

set(APPROVAL_FRAMEWORK_HEADERS
    tests/approval/approval_test_config.hpp
    tests/approval/result_formatter.hpp
    tests/approval/visualization_service.hpp
    tests/approval/comparison_service.hpp
    tests/approval/diff_launcher.hpp
    tests/approval/approval_test_orchestrator.hpp
)

# Create static library for the bounded context
add_library(image_analysis STATIC ${IMAGE_ANALYSIS_SOURCES})

# Link libraries using modern CMake targets
target_link_libraries(image_analysis 
    PUBLIC ${OpenCV_LIBS}  # Use OpenCV_LIBS for consistency
)

# Set include directories for the library
target_include_directories(image_analysis 
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/..  # For access to existing headers
    PRIVATE
        ${OpenCV_INCLUDE_DIRS}
)

# Include approval framework headers for tests that need them
target_include_directories(image_analysis 
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/tests/approval  # For approval testing framework
)

# Compiler flags
if(MSVC)
    target_compile_options(image_analysis PRIVATE
        /W4  # High warning level
        $<$<CONFIG:Debug>:/Od /Zi>
        $<$<CONFIG:Release>:/O2 /DNDEBUG>
    )
else()
    target_compile_options(image_analysis PRIVATE
        -Wall -Wextra -Wpedantic
        $<$<CONFIG:Debug>:-g -O0>
        $<$<CONFIG:Release>:-O3 -DNDEBUG>
    )
endif()

# Function to configure Boost Test linking for a target
function(configure_boost_test_target target_name)
    target_link_libraries(${target_name} PRIVATE 
        Boost::unit_test_framework 
        image_analysis 
        ${OpenCV_LIBS}  # Use OpenCV_LIBS variable for consistency
    )
    # Note: No BOOST_TEST_DYN_LINK definition needed for static linking
endfunction()

enable_testing()

# =============================================================================
# Test Executables and Configuration
# =============================================================================

# Domain tests (no external dependencies)
add_executable(test_image_analysis_domain tests/test_image_analysis_domain.cpp)
configure_boost_test_target(test_image_analysis_domain)
add_test(NAME DomainTests COMMAND test_image_analysis_domain)

# Domain validation tests (input validation and invariant enforcement)
add_executable(test_domain_validation tests/test_domain_validation.cpp)
configure_boost_test_target(test_domain_validation)
add_test(NAME DomainValidationTests COMMAND test_domain_validation)

# OpenCV integration tests
add_executable(test_opencv_analyzer tests/test_opencv_analyzer.cpp)
configure_boost_test_target(test_opencv_analyzer)
add_test(NAME OpenCVTests COMMAND test_opencv_analyzer)

# Application service tests (input validation, configuration)
add_executable(test_image_analysis_service tests/test_image_analysis_service.cpp)
configure_boost_test_target(test_image_analysis_service)
add_test(NAME ApplicationServiceTests COMMAND test_image_analysis_service)

# Approval tests using clean architecture framework
add_executable(test_approval_with_pitrac_images 
    tests/test_approval_with_pitrac_images.cpp
    ${APPROVAL_FRAMEWORK_SOURCES}
)
configure_boost_test_target(test_approval_with_pitrac_images)
add_test(NAME ApprovalTests COMMAND test_approval_with_pitrac_images)

# Set test properties
set_tests_properties(DomainTests PROPERTIES
    TIMEOUT 30
    LABELS "unit;domain"
)

set_tests_properties(DomainValidationTests PROPERTIES
    TIMEOUT 30
    LABELS "unit;domain;validation"
)

set_tests_properties(OpenCVTests PROPERTIES
    TIMEOUT 60
    LABELS "integration;opencv"
)

set_tests_properties(ApplicationServiceTests PROPERTIES
    TIMEOUT 30
    LABELS "unit;application;validation"
)

set_tests_properties(ApprovalTests PROPERTIES
    TIMEOUT 120
    LABELS "approval;pitrac;images;clean-architecture"
)

# Install rules
install(TARGETS image_analysis
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES ${IMAGE_ANALYSIS_HEADERS}
    DESTINATION include/ImageAnalysis
)

# Install approval testing framework headers (for reuse in other projects)
install(FILES ${APPROVAL_FRAMEWORK_HEADERS}
    DESTINATION include/ImageAnalysis/approval
)

# Development convenience targets
add_custom_target(run_tests
    COMMAND ctest --output-on-failure
    DEPENDS test_image_analysis_domain test_opencv_analyzer test_image_analysis_service test_approval_with_pitrac_images
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running all image analysis tests"
)

add_custom_target(run_domain_tests
    COMMAND test_image_analysis_domain
    DEPENDS test_image_analysis_domain
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running domain tests only"
)

# TEMPORARILY DISABLED: Domain validation tests convenience target (Boost linking issue)
# add_custom_target(run_domain_validation_tests
#     COMMAND test_domain_validation
#     DEPENDS test_domain_validation
#     WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
#     COMMENT "Running domain validation tests only"
# )

add_custom_target(run_integration_tests
    COMMAND test_opencv_analyzer
    DEPENDS test_opencv_analyzer
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running integration tests only"
)

add_custom_target(run_approval_tests
    COMMAND test_approval_with_pitrac_images
    DEPENDS test_approval_with_pitrac_images
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMENT "Running approval tests with clean architecture framework"
)

# Print configuration summary
message(STATUS "Image Analysis Bounded Context Configuration:")
message(STATUS "  OpenCV version: ${OpenCV_VERSION}")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  C++ standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "  Tests enabled: ${Boost_FOUND}")
