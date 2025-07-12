/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file interfaces.hpp
 * @brief Domain interfaces for image analysis bounded context
 * 
 * Technology-agnostic interfaces that define the core capabilities
 * of the image analysis domain. These interfaces will be implemented
 * by infrastructure adapters (OpenCV, YOLO, etc.).
 */

#pragma once

#include "value_objects.hpp"
#include "analysis_results.hpp"
#include <memory>
#include <string>
#include <vector>

namespace golf_sim::image_analysis::domain
{
    /**
     * @brief Core interface for golf ball image analysis capabilities
     * 
     * This interface abstracts the four key image analysis capabilities
     * needed for golf ball tracking, independent of the underlying
     * implementation technology (OpenCV, YOLO, TensorFlow, etc.).
     */
    class IImageAnalyzer
    {
    public:
        virtual ~IImageAnalyzer() = default;

        /**
         * @brief Analyze image to detect if ball is present on tee
         * @param image The image to analyze
         * @param expected_position Optional hint about where ball should be
         * @return Result indicating ball state and position
         */
        [[nodiscard]] virtual TeedBallResult AnalyzeTeedBall(
            const ImageBuffer& image,
            const std::optional<BallPosition>& expected_position = std::nullopt
        ) = 0;

        /**
         * @brief Detect movement indicating shot in progress
         * @param image_sequence Sequence of images to analyze for movement
         * @param reference_ball_position Known position of ball before movement
         * @return Result indicating if movement was detected and its characteristics
         */
        [[nodiscard]] virtual MovementResult DetectMovement(
            const std::vector<ImageBuffer>& image_sequence,
            const BallPosition& reference_ball_position
        ) = 0;

        /**
         * @brief Analyze strobed ball flight image for multiple ball positions
         * @param strobed_image High-speed strobed image showing ball flight
         * @param calibration_reference Reference ball for size/distance calibration
         * @return Analysis of ball positions, velocity, and spin
         */
        [[nodiscard]] virtual FlightAnalysisResult AnalyzeBallFlight(
            const ImageBuffer& strobed_image,
            const BallPosition& calibration_reference
        ) = 0;

        /**
         * @brief Detect if ball has been reset on tee
         * @param current_image Current image to analyze
         * @param previous_ball_position Last known ball position
         * @return Result indicating if ball was reset
         */
        [[nodiscard]] virtual TeedBallResult DetectBallReset(
            const ImageBuffer& current_image,
            const BallPosition& previous_ball_position
        ) = 0;

        // Analyzer metadata and capabilities
        [[nodiscard]] virtual std::string GetAnalyzerName() const = 0;
        [[nodiscard]] virtual std::string GetVersion() const = 0;
        [[nodiscard]] virtual bool SupportsRealTime() const = 0;
    };

    /**
     * @brief Factory interface for creating image analyzers
     * 
     * Enables runtime selection of analyzer implementation:
     * - "opencv" - Traditional OpenCV Hough circle detection
     * - "yolo_v5" - YOLO v5 machine learning detection  
     * - "tensorflow_lite" - TensorFlow Lite embedded models
     * - "hybrid" - Combination of multiple approaches
     */
    class IImageAnalyzerFactory
    {
    public:
        virtual ~IImageAnalyzerFactory() = default;

        [[nodiscard]] virtual std::unique_ptr<IImageAnalyzer> CreateAnalyzer(
            const std::string& analyzer_type = "opencv"
        ) = 0;

        [[nodiscard]] virtual std::vector<std::string> GetAvailableAnalyzers() const = 0;

        [[nodiscard]] virtual bool IsAnalyzerAvailable(const std::string& analyzer_type) const = 0;
    };

    /**
     * @brief Repository interface for storing and retrieving analysis results
     * 
     * Allows persisting analysis results for debugging, training data
     * collection, or performance analysis.
     */
    class IAnalysisResultRepository
    {
    public:
        virtual ~IAnalysisResultRepository() = default;
        virtual void StoreTeedBallResult(const TeedBallResult& result,
                                         const ImageBuffer& image) = 0;
        virtual void StoreMovementResult(const MovementResult& result,
                                         const std::vector<ImageBuffer>& images) = 0;
        virtual void StoreFlightAnalysisResult(const FlightAnalysisResult& result,
                                               const ImageBuffer& image) = 0;

        [[nodiscard]] virtual std::vector<TeedBallResult> GetTeedBallResults(
            std::chrono::microseconds start_time,
            std::chrono::microseconds end_time) = 0;
    };

    /**
     * @brief Configuration repository interface
     * 
     * Manages analyzer configuration settings that can be persisted
     * and modified at runtime.
     */
    class IAnalyzerConfigRepository
    {
    public:
        virtual ~IAnalyzerConfigRepository() = default;

        virtual void SetAnalyzerType(const std::string& analyzer_type) = 0;
        [[nodiscard]] virtual std::string GetAnalyzerType() const = 0;

        virtual void SetConfidenceThreshold(double threshold) = 0; // Should be 0.0-1.0
        [[nodiscard]] virtual double GetConfidenceThreshold() const = 0;

        virtual void SetDebugMode(bool enabled) = 0;
        [[nodiscard]] virtual bool IsDebugModeEnabled() const = 0;

        virtual void SetModelPath(const std::string& path) = 0;
        [[nodiscard]] virtual std::string GetModelPath() const = 0;
    };
} // namespace golf_sim::image_analysis::domain
