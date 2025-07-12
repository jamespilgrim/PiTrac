/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file comparison_service.hpp
 * @brief Service for comparing approval test artifacts
 * 
 * Handles comparison of text and image files for approval testing.
 * Follows Single Responsibility Principle - only concerned with comparison logic.
 */

#pragma once

#include <string>
#include <memory>
#include <opencv2/opencv.hpp>

namespace golf_sim::image_analysis::testing {

/**
 * @brief Result of a comparison operation
 */
struct ComparisonResult {
    bool matches;
    std::string failure_reason;
    
    ComparisonResult(bool matches, const std::string& reason = "")
        : matches(matches), failure_reason(reason) {}
    
    operator bool() const { return matches; }
};

/**
 * @brief Interface for comparison strategies
 * 
 * Allows different comparison algorithms while maintaining dependency inversion.
 */
class IComparisonService {
public:
    virtual ~IComparisonService() = default;
    
    /**
     * @brief Compare two text strings for equality
     * @param received The received content
     * @param approved The approved content
     * @return Comparison result
     */
    virtual ComparisonResult CompareText(const std::string& received, 
                                       const std::string& approved) const = 0;
    
    /**
     * @brief Compare two image files for equality
     * @param received_path Path to received image
     * @param approved_path Path to approved image
     * @return Comparison result
     */
    virtual ComparisonResult CompareImages(const std::string& received_path,
                                         const std::string& approved_path) const = 0;
};

/**
 * @brief Standard comparison service implementation
 * 
 * Provides exact comparison for text and pixel-perfect comparison for images.
 */
class StandardComparisonService : public IComparisonService {
public:
    ComparisonResult CompareText(const std::string& received, 
                               const std::string& approved) const override;
    
    ComparisonResult CompareImages(const std::string& received_path,
                                 const std::string& approved_path) const override;

private:
    /**
     * @brief Check if an image is completely black (empty baseline)
     * @param image The image to check
     * @return true if image is empty baseline
     */
    bool IsEmptyBaseline(const cv::Mat& image) const;
    
    /**
     * @brief Check if two images have identical pixel values
     * @param img1 First image
     * @param img2 Second image
     * @return true if images are pixel-perfect identical
     */
    bool AreImagesIdentical(const cv::Mat& img1, const cv::Mat& img2) const;
};

/**
 * @brief Fuzzy comparison service for tolerant comparisons
 * 
 * Allows small differences in images due to compression or minor variations.
 */
class FuzzyComparisonService : public IComparisonService {
public:
    /**
     * @brief Constructor with tolerance settings
     * @param image_tolerance Maximum allowed difference for image comparison (0.0-1.0)
     */
    explicit FuzzyComparisonService(double image_tolerance = 0.01);
    
    ComparisonResult CompareText(const std::string& received, 
                               const std::string& approved) const override;
    
    ComparisonResult CompareImages(const std::string& received_path,
                                 const std::string& approved_path) const override;

private:
    double image_tolerance_;
    
    /**
     * @brief Calculate structural similarity between two images
     * @param img1 First image
     * @param img2 Second image
     * @return Similarity score (0.0-1.0, where 1.0 is identical)
     */
    double CalculateImageSimilarity(const cv::Mat& img1, const cv::Mat& img2) const;
};

/**
 * @brief Factory for creating comparison services
 */
class ComparisonServiceFactory {
public:
    enum class ServiceType {
        STANDARD,
        FUZZY
    };
    
    static std::unique_ptr<IComparisonService> Create(ServiceType type, 
                                                    double fuzzy_tolerance = 0.01);
};

} // namespace golf_sim::image_analysis::testing
