/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file value_objects.hpp
 * @brief Domain value objects for image analysis bounded context
 * 
 * Core immutable data structures representing business concepts
 * in the image analysis domain. These are technology-agnostic
 * and contain no dependencies on OpenCV, YOLO, or other frameworks.
 */

#pragma once

#include <chrono>
#include <cmath>
#include <stdexcept>
#include <string>
#include <vector>
#include <opencv2/core.hpp>  // Only for cv::Mat, cv::Point2f, cv::Vec3d - consider abstracting later

namespace golf_sim::image_analysis::domain
{
    /**
     * @brief Represents a ball position with confidence and metadata
     *
     * Immutable value object representing the position of a golf ball
     * in an image with associated confidence and detection metadata.
     */
    struct BallPosition
    {
        double x_pixels;
        double y_pixels;
        double radius_pixels;
        double confidence; // 0.0 to 1.0
        std::chrono::microseconds timestamp;
        std::string detection_method; // e.g., "hough_circles", "yolo_v5"

        // Default constructor
        BallPosition() : x_pixels(0.0), y_pixels(0.0), radius_pixels(0.0),
                         confidence(0.0), timestamp(std::chrono::microseconds{0}),
                         detection_method("unknown")
        {
        }

        // Parameterized constructor
        BallPosition(double x, double y, double radius, double conf = 1.0,
                     std::chrono::microseconds ts = std::chrono::microseconds{0},
                     const std::string& method = "unknown")
            : x_pixels(x), y_pixels(y), radius_pixels(radius),
              confidence(conf), timestamp(ts), detection_method(method)
        {
            ValidateParameters();
        }

        [[nodiscard]] bool IsValid() const
        {
            return confidence > 0.0 && radius_pixels > 0.0;
        }

        // Distance calculation for ball movement detection
        [[nodiscard]] double DistanceFrom(const BallPosition& other) const
        {
            double dx = x_pixels - other.x_pixels;
            double dy = y_pixels - other.y_pixels;
            return std::sqrt(dx * dx + dy * dy);
        }

        // Check if two positions are nearly equal within tolerance
        [[nodiscard]] bool IsNearlyEqual(const BallPosition& other, double tolerance) const
        {
            if (tolerance < 0.0)
            {
                throw std::invalid_argument("Tolerance must be non-negative");
            }
            return DistanceFrom(other) <= tolerance;
        }

    private:
        void ValidateParameters() const
        {
            if (confidence < 0.0 || confidence > 1.0)
            {
                throw std::invalid_argument("Confidence must be between 0.0 and 1.0");
            }
            if (radius_pixels < 0.0)
            {
                throw std::invalid_argument("Radius must be non-negative");
            }
            if (std::isnan(x_pixels) || std::isnan(y_pixels) || std::isnan(radius_pixels))
            {
                throw std::invalid_argument("Position coordinates cannot be NaN");
            }
            if (std::isinf(x_pixels) || std::isinf(y_pixels) || std::isinf(radius_pixels))
            {
                throw std::invalid_argument("Position coordinates cannot be infinite");
            }
        }
    };

    /**
     * @brief Represents an image buffer with timing and metadata
     *
     * Contains the actual image data along with capture timing
     * and metadata needed for analysis.
     */
    struct ImageBuffer
    {
        cv::Mat data; // The actual image data
        std::chrono::microseconds timestamp; // When image was captured
        std::string camera_id; // Which camera captured this
        std::string metadata; // Additional metadata (exposure, etc.)

        ImageBuffer() = default;

        ImageBuffer(const cv::Mat& image,
                    std::chrono::microseconds ts = std::chrono::microseconds{0},
                    const std::string& cam_id = "",
                    const std::string& meta = "")
            : data(image.clone()), timestamp(ts), camera_id(cam_id), metadata(meta)
        {
            ValidateImage();
        }

        [[nodiscard]] bool IsValid() const
        {
            return !data.empty();
        }

        // Get time difference between this and another image
        [[nodiscard]] std::chrono::microseconds TimeDifferenceFrom(const ImageBuffer& other) const
        {
            return timestamp - other.timestamp;
        }

    private:
        void ValidateImage() const
        {
            if (data.empty())
            {
                throw std::invalid_argument("Image data cannot be empty");
            }
            if (data.rows <= 0 || data.cols <= 0)
            {
                throw std::invalid_argument("Image must have positive dimensions");
            }
        }
    };

    /**
     * @brief Ball state enumeration for tee detection
     */
    enum class BallState
    {
        ABSENT, // No ball detected on tee
        TEED, // Ball is stationary and ready for shot
        MOVING, // Ball is in motion (during shot)
        RESET // Ball has been reset/replaced after previous analysis
    };

    /**
     * @brief Convert BallState to string for logging/debugging
     */
    inline std::string ToString(BallState state)
    {
        switch (state)
        {
        case BallState::ABSENT: return "ABSENT";
        case BallState::TEED: return "TEED";
        case BallState::MOVING: return "MOVING";
        case BallState::RESET: return "RESET";
        default: return "UNKNOWN";
        }
    }

    /**
     * @brief Stream operator for BallState (required by Boost Test)
     */
    inline std::ostream& operator<<(std::ostream& os, BallState state)
    {
        return os << ToString(state);
    }

    /**
     * @brief Analysis confidence levels
     */
    enum class ConfidenceLevel
    {
        VERY_LOW, // 0.0 - 0.3
        LOW, // 0.3 - 0.5
        MEDIUM, // 0.5 - 0.7
        HIGH, // 0.7 - 0.9
        VERY_HIGH // 0.9 - 1.0
    };

    /**
     * @brief Convert confidence score to level
     */
    [[nodiscard]] inline ConfidenceLevel GetConfidenceLevel(double confidence)
    {
        if (confidence < 0.0 || confidence > 1.0)
        {
            throw std::invalid_argument("Confidence must be between 0.0 and 1.0");
        }
        if (confidence < 0.3) return ConfidenceLevel::VERY_LOW;
        if (confidence < 0.5) return ConfidenceLevel::LOW;
        if (confidence < 0.7) return ConfidenceLevel::MEDIUM;
        if (confidence < 0.9) return ConfidenceLevel::HIGH;
        return ConfidenceLevel::VERY_HIGH;
    }

    /**
     * @brief Convert ConfidenceLevel to string for logging/debugging
     */
    inline std::string ToString(ConfidenceLevel level)
    {
        switch (level)
        {
        case ConfidenceLevel::VERY_LOW: return "VERY_LOW";
        case ConfidenceLevel::LOW: return "LOW";
        case ConfidenceLevel::MEDIUM: return "MEDIUM";
        case ConfidenceLevel::HIGH: return "HIGH";
        case ConfidenceLevel::VERY_HIGH: return "VERY_HIGH";
        default: return "UNKNOWN";
        }
    }

    /**
     * @brief Stream operator for ConfidenceLevel (required by Boost Test)
     */
    inline std::ostream& operator<<(std::ostream& os, ConfidenceLevel level)
    {
        return os << ToString(level);
    }
} // namespace golf_sim::image_analysis::domain
