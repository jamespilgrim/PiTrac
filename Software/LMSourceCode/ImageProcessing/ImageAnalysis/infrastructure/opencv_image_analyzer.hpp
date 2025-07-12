/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file opencv_image_analyzer.hpp
 * @brief OpenCV-based implementation of image analysis interface
 * 
 * Wraps the existing sophisticated OpenCV ball detection logic
 * (BallImageProc and GolfSimCamera) behind the domain interface.
 * This preserves all the complex Hough circle detection, strobed
 * ball analysis, and movement detection while providing a clean
 * abstraction for future AI/ML integration.
 */

#pragma once

#include "../domain/interfaces.hpp"
#include "../domain/analysis_results.hpp"
#include <opencv2/opencv.hpp>

namespace golf_sim::image_analysis::infrastructure {

    /**
     * @brief Simplified OpenCV-based implementation of IImageAnalyzer
     * 
     * This implementation provides basic OpenCV-based ball detection
     * using Hough circle detection. It serves as a working prototype
     * for the bounded context while the full integration with existing
     * BallImageProc can be completed later.
     */
    class OpenCVImageAnalyzer : public domain::IImageAnalyzer {
    public:
        OpenCVImageAnalyzer();
        ~OpenCVImageAnalyzer() override = default;

        // Domain interface implementation
        domain::TeedBallResult AnalyzeTeedBall(
            const domain::ImageBuffer& image,
            const std::optional<domain::BallPosition>& expected_position = std::nullopt
        ) override;

        domain::MovementResult DetectMovement(
            const std::vector<domain::ImageBuffer>& image_sequence,
            const domain::BallPosition& reference_ball_position
        ) override;

        domain::FlightAnalysisResult AnalyzeBallFlight(
            const domain::ImageBuffer& strobed_image,
            const domain::BallPosition& calibration_reference
        ) override;

        domain::TeedBallResult DetectBallReset(
            const domain::ImageBuffer& current_image,
            const domain::BallPosition& previous_ball_position
        ) override;

        // Analyzer metadata
        std::string GetAnalyzerName() const override { return "OpenCV Image Analyzer"; }
        std::string GetVersion() const override { return "1.0.0-simplified"; }
        bool SupportsRealTime() const override { return true; }

        // OpenCV-specific configuration
        void SetHoughParameters(double param1, double param2, double dp = 1.0);
        void SetRadiusLimits(int min_radius, int max_radius);    private:
        // Configuration parameters for Hough Circle detection
        static constexpr double DEFAULT_HOUGH_PARAM1 = 100.0;
        static constexpr double DEFAULT_HOUGH_PARAM2 = 30.0;
        static constexpr double DEFAULT_HOUGH_DP = 1.0;
        static constexpr int DEFAULT_MIN_RADIUS = 10;
        static constexpr int DEFAULT_MAX_RADIUS = 100;
        static constexpr double MOVEMENT_THRESHOLD = 2.0;
        static constexpr double VELOCITY_SCALING_FACTOR = 20.0;
        static constexpr double RESET_DISTANCE_THRESHOLD = 100.0;
        static constexpr double TEMPORAL_SPACING_US = 5000.0;  // 5ms assumption
        
        double hough_param1_ = DEFAULT_HOUGH_PARAM1;
        double hough_param2_ = DEFAULT_HOUGH_PARAM2;
        double hough_dp_ = DEFAULT_HOUGH_DP;
        int min_radius_ = DEFAULT_MIN_RADIUS;
        int max_radius_ = DEFAULT_MAX_RADIUS;
        
        // Core detection methods
        std::vector<domain::BallPosition> DetectCircles(const cv::Mat& image) const;
        static domain::BallPosition SelectBestCandidate(
            const std::vector<domain::BallPosition>& candidates,
            const std::optional<domain::BallPosition>& expected_position);
          // Helper methods
        double CalculateConfidence(const domain::BallPosition& position, const cv::Mat& image) const;
        static bool IsValidBallPosition(const domain::BallPosition& position, const cv::Mat& image);
        static cv::Mat PreprocessImage(const cv::Mat& input);
        
        // Movement detection helpers
        static std::vector<cv::Point2f> CalculateOpticalFlow(
            const cv::Mat& prev_frame, const cv::Mat& curr_frame);
        static double CalculateMovementMagnitude(const std::vector<cv::Point2f>& flow);
        
        // Error result creators
        static domain::TeedBallResult CreateErrorResult(const std::string& error_message);
        static domain::MovementResult CreateMovementErrorResult(const std::string& error_message);
        static domain::FlightAnalysisResult CreateFlightErrorResult(const std::string& error_message);
    };

} // namespace golf_sim::image_analysis::infrastructure
