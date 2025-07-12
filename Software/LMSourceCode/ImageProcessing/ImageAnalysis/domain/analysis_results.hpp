/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file analysis_results.hpp
 * @brief Domain result objects for image analysis operations
 * 
 * Result objects that encapsulate the outcomes of different
 * image analysis operations with confidence scores and debug info.
 */

#pragma once

#include "value_objects.hpp"
#include <vector>
#include <optional>
#include <opencv2/core.hpp>  // For cv::Point2f, cv::Vec3d

namespace golf_sim::image_analysis::domain
{
    /**
     * @brief Result of teed ball analysis
     */
    struct TeedBallResult
    {
        BallState state = BallState::ABSENT;
        std::optional<BallPosition> position;
        double confidence = 0.0; // Overall confidence in the analysis
        std::string analysis_method; // e.g., "opencv_hough", "yolo_v5", etc.
        std::vector<std::string> debug_info; // Debug information for troubleshooting

        [[nodiscard]] bool HasBall() const
        {
            return state == BallState::TEED || state == BallState::RESET;
        }

        [[nodiscard]] ConfidenceLevel GetConfidenceLevel() const
        {
            return domain::GetConfidenceLevel(confidence);
        }
    };

    /**
     * @brief Result of movement detection analysis
     */
    struct MovementResult
    {
        bool movement_detected = false;
        std::optional<BallPosition> last_known_position;
        double movement_confidence = 0.0;
        double movement_magnitude = 0.0; // Magnitude of detected movement
        std::vector<cv::Point2f> motion_vectors; // Optional motion field data
        std::chrono::microseconds time_since_first_movement{0};
        std::string analysis_method;
        std::vector<std::string> debug_info;

        [[nodiscard]] ConfidenceLevel GetConfidenceLevel() const
        {
            return domain::GetConfidenceLevel(movement_confidence);
        }
    };

    /**
     * @brief Result of strobed ball flight analysis
     */
    struct FlightAnalysisResult
    {
        std::vector<BallPosition> detected_balls; // Multiple ball positions from strobed image
        std::optional<cv::Vec3d> spin_rates; // x, y, z rotation rates (degrees/second)
        std::optional<cv::Vec3d> velocity_vector; // 3D velocity vector (m/s)
        double temporal_spacing_us = 0.0; // Time between ball exposures (microseconds)
        double confidence = 0.0; // Overall confidence in analysis
        std::string analysis_method;
        std::vector<std::string> debug_info;

        [[nodiscard]] bool HasMultipleBalls() const
        {
            return detected_balls.size() >= 2;
        }

        [[nodiscard]] bool HasValidSpinData() const
        {
            return spin_rates.has_value() && confidence > 0.5;
        }

        [[nodiscard]] bool HasValidVelocityData() const
        {
            return velocity_vector.has_value() && confidence > 0.5;
        }

        [[nodiscard]] ConfidenceLevel GetConfidenceLevel() const
        {
            return domain::GetConfidenceLevel(confidence);
        }
    };

    /**
     * @brief Generic analysis result for operations that might fail
     */
    template <typename T>
    struct AnalysisResult
    {
        bool success = false;
        T data;
        std::string error_message;
        std::vector<std::string> debug_info;

        [[nodiscard]] static AnalysisResult<T> Success(const T& result)
        {
            return {true, result, "", {}};
        }

        [[nodiscard]] static AnalysisResult<T> Failure(const std::string& error)
        {
            return {false, T{}, error, {}};
        }

        [[nodiscard]] bool IsSuccess() const { return success; }
        [[nodiscard]] bool IsFailure() const { return !success; }
    };
} // namespace golf_sim::image_analysis::domain
