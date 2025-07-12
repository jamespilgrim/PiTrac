/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file visualization_service.hpp
 * @brief Service for creating test visualization images
 * 
 * Handles the creation of visualization images for approval testing.
 * Follows Single Responsibility Principle - only concerned with visualization.
 */

#pragma once

#include "../../domain/analysis_results.hpp"
#include "approval_test_config.hpp"
#include <opencv2/opencv.hpp>
#include <string>
#include <memory>

namespace golf_sim::image_analysis::testing {

/**
 * @brief Interface for visualization services
 * 
 * Allows for different visualization strategies while maintaining dependency inversion.
 */
class IVisualizationService {
public:
    virtual ~IVisualizationService() = default;
    
    /**
     * @brief Create a visualization image showing analysis results
     * @param original_image The original image to annotate
     * @param result The analysis result to visualize
     * @param output_path Path where the visualization should be saved
     * @return true if visualization was created successfully
     */
    virtual bool CreateVisualization(const cv::Mat& original_image,
                                   const domain::TeedBallResult& result,
                                   const std::string& output_path) const = 0;
    
    /**
     * @brief Create an empty baseline image with the specified dimensions
     * @param width Image width
     * @param height Image height
     * @param output_path Path where the empty image should be saved
     * @return true if empty image was created successfully
     */
    virtual bool CreateEmptyBaseline(int width, int height, const std::string& output_path) const = 0;
};

/**
 * @brief OpenCV-based visualization service
 * 
 * Concrete implementation using OpenCV for image processing and annotation.
 */
class OpenCVVisualizationService : public IVisualizationService {
public:
    /**
     * @brief Constructor with dependency injection
     * @param config Configuration settings for visualization
     */
    explicit OpenCVVisualizationService(const ApprovalTestConfig& config);
    
    bool CreateVisualization(const cv::Mat& original_image,
                           const domain::TeedBallResult& result,
                           const std::string& output_path) const override;
    
    bool CreateEmptyBaseline(int width, int height, const std::string& output_path) const override;

private:
    const ApprovalTestConfig& config_;
    
    /**
     * @brief Convert semantic color name to OpenCV Scalar
     * @param color_name Semantic color name (e.g., "green", "red")
     * @return OpenCV Scalar in BGR format
     */
    cv::Scalar GetColorScalar(const std::string& color_name) const;
    
    /**
     * @brief Draw ball detection annotations on the image
     * @param image Image to annotate (modified in place)
     * @param result Analysis result containing detection information
     */
    void DrawBallDetection(cv::Mat& image, const domain::TeedBallResult& result) const;
    
    /**
     * @brief Draw "no ball detected" annotation on the image
     * @param image Image to annotate (modified in place)
     */
    void DrawNoBallDetected(cv::Mat& image) const;
};

/**
 * @brief Factory for creating visualization services
 */
class VisualizationServiceFactory {
public:
    enum class ServiceType {
        OPENCV_STANDARD
    };
    
    static std::unique_ptr<IVisualizationService> Create(ServiceType type, 
                                                        const ApprovalTestConfig& config);
};

} // namespace golf_sim::image_analysis::testing
