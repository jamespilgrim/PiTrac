/*
 * Test Utilities for Camera Bounded Context
 * 
 * Common utilities and fixtures for Camera unit tests.
 * Provides reusable helpers and test data.
 */

#pragma once

#include <boost/test/unit_test.hpp>
#include "camera_platform.hpp"
#include <vector>
#include <utility>
#include <chrono>
#include <climits>

namespace camera_test_utils {

    // Common test data for camera domain types
    struct CommonTestData {
        static std::vector<std::pair<unsigned int, unsigned int>> getValidSizes() {
            return {
                {640, 480},      // VGA
                {800, 600},      // SVGA
                {1024, 768},     // XGA
                {1280, 720},     // HD 720p
                {1920, 1080},    // Full HD 1080p
                {3840, 2160},    // 4K UHD
                {0, 0},          // Edge case: zero size
                {1, 1},          // Edge case: minimum size
                {4294967295U, 4294967295U}  // Edge case: maximum size
            };
        }
        
        static std::vector<int> getValidTransforms() {
            return {0, 90, 180, 270, -90, -180, -270, 360, 450};
        }
        
        static std::vector<unsigned int> getValidPixelFormats() {
            return {
                0x32315659,  // YV12
                0x32315559,  // YUV
                0x56595559,  // YUYV
                0x50424752,  // RGBP
                0x42475224,  // RGB4
                0,           // Edge case: no format
                4294967295U  // Edge case: maximum value
            };
        }        static std::vector<int> getValidColorSpaces() {
            return {0, 1, 2, 3, -1, 100, 2147483647, -2147483647-1};
        }
    };

    // Test fixture for domain type testing
    struct DomainTypeFixture {
        DomainTypeFixture() {
            BOOST_TEST_MESSAGE("Setting up domain type test fixture");
        }
        
        ~DomainTypeFixture() {        
            BOOST_TEST_MESSAGE("Tearing down domain type test fixture");
        }
        
        // Helper methods for common assertions
        void assertSizeEquals(const golf_sim::camera::domain::Size& actual, 
                              unsigned int expected_width, 
                              unsigned int expected_height) {
            BOOST_CHECK_EQUAL(actual.width, expected_width);
            BOOST_CHECK_EQUAL(actual.height, expected_height);
        }
        
        void assertTransformEquals(const golf_sim::camera::domain::Transform& actual, 
                                   int expected_value) {
            BOOST_CHECK_EQUAL(actual.value, expected_value);
        }
        
        void assertPixelFormatEquals(const golf_sim::camera::domain::PixelFormat& actual, 
                                     unsigned int expected_fourcc) {
            BOOST_CHECK_EQUAL(actual.fourcc, expected_fourcc);
        }
        
        void assertColorSpaceEquals(const golf_sim::camera::domain::ColorSpace& actual, 
                                    int expected_value) {
            BOOST_CHECK_EQUAL(actual.value, expected_value);
        }
    };

    // Parametric test helper for testing multiple values
    template<typename T, typename TestFunc>
    void runParametricTest(const std::vector<T>& testValues, TestFunc testFunction) {
        for (const auto& value : testValues) {
            testFunction(value);
        }
    }

    // Performance test helper for measuring basic operations
    struct PerformanceFixture {
        PerformanceFixture() : start_time(std::chrono::high_resolution_clock::now()) {}
        
        ~PerformanceFixture() {
            auto end_time = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(
                end_time - start_time).count();
            BOOST_TEST_MESSAGE("Test completed in " << duration << " microseconds");
        }
        
    private:
        std::chrono::high_resolution_clock::time_point start_time;
    };

} // namespace camera_test_utils
