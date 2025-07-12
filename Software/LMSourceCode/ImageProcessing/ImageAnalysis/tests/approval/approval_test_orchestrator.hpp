/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file approval_test_orchestrator.hpp
 * @brief Main orchestrator for approval testing workflow
 * 
 * Coordinates all approval testing services following the Facade pattern.
 * Provides a simplified interface for running approval tests while delegating
 * to specialized services following Single Responsibility Principle.
 */

#pragma once

#include "approval_test_config.hpp"
#include "result_formatter.hpp"
#include "visualization_service.hpp"
#include "comparison_service.hpp"
#include "diff_launcher.hpp"
#include "../../domain/analysis_results.hpp"
#include "../../domain/value_objects.hpp"
#include "../../infrastructure/opencv_image_analyzer.hpp"
#include <opencv2/opencv.hpp>
#include <string>
#include <memory>

namespace golf_sim::image_analysis::testing {

/**
 * @brief Result of an approval test operation
 */
struct ApprovalTestResult {
    bool passed;
    std::string test_name;
    std::string failure_message;
    bool text_matches;
    bool images_match;
    
    ApprovalTestResult(const std::string& name) 
        : passed(false), test_name(name), text_matches(false), images_match(false) {}
};

/**
 * @brief Main orchestrator for approval testing
 * 
 * Coordinates all approval testing services and provides a clean interface
 * for running approval tests. Follows Facade pattern to hide complexity.
 */
class ApprovalTestOrchestrator {
public:
    /**
     * @brief Constructor with dependency injection
     * 
     * @param config Configuration settings
     * @param formatter Result formatting strategy
     * @param visualizer Visualization service
     * @param comparator Comparison service
     * @param diff_launcher Diff tool launcher
     */
    ApprovalTestOrchestrator(
        const ApprovalTestConfig& config,
        std::unique_ptr<IResultFormatter> formatter,
        std::unique_ptr<IVisualizationService> visualizer,
        std::unique_ptr<IComparisonService> comparator,
        std::unique_ptr<IDiffLauncher> diff_launcher
    );
    
    /**
     * @brief Run approval test for a single image
     * 
     * @param image_filename Name of image file in PiTrac images directory
     * @param test_name Unique test identifier
     * @param analyzer Image analyzer to use for analysis
     * @param timestamp Test timestamp for consistent results
     * @return Approval test result
     */
    ApprovalTestResult RunImageApprovalTest(
        const std::string& image_filename,
        const std::string& test_name,
        infrastructure::OpenCVImageAnalyzer& analyzer,
        const std::chrono::microseconds& timestamp
    );
    
    /**
     * @brief Run approval test for movement analysis
     * 
     * @param image_sequence Sequence of images for movement analysis
     * @param reference_position Reference ball position
     * @param test_name Unique test identifier
     * @param analyzer Image analyzer to use for analysis
     * @return Approval test result
     */
    ApprovalTestResult RunMovementApprovalTest(
        const std::vector<domain::ImageBuffer>& image_sequence,
        const domain::BallPosition& reference_position,
        const std::string& test_name,
        infrastructure::OpenCVImageAnalyzer& analyzer
    );

private:
    const ApprovalTestConfig& config_;
    std::unique_ptr<IResultFormatter> formatter_;
    std::unique_ptr<IVisualizationService> visualizer_;
    std::unique_ptr<IComparisonService> comparator_;
    std::unique_ptr<IDiffLauncher> diff_launcher_;
    
    /**
     * @brief Load image from PiTrac test images directory
     * @param filename Image filename
     * @return Loaded image matrix
     * @throws std::runtime_error if image cannot be loaded
     */
    cv::Mat LoadPiTracImage(const std::string& filename) const;
    
    /**
     * @brief Generate file paths for approval artifacts
     * @param test_name Test identifier
     * @param suffix File suffix (.approved or .received)
     * @param extension File extension (.txt or .png)
     * @return Generated file path
     */
    std::string GenerateArtifactPath(const std::string& test_name, 
                                   const std::string& suffix,
                                   const std::string& extension) const;
    
    /**
     * @brief Save received artifacts (text and visualization)
     * @param test_name Test identifier
     * @param formatted_result Formatted text result
     * @param original_image Original image for visualization
     * @param analysis_result Analysis result for visualization
     * @return true if artifacts saved successfully
     */
    bool SaveReceivedArtifacts(const std::string& test_name,
                             const std::string& formatted_result,
                             const cv::Mat& original_image,
                             const domain::TeedBallResult& analysis_result) const;
    
    /**
     * @brief Handle the case where no approved files exist (new test)
     * @param test_name Test identifier
     * @param received_text_path Path to received text file
     * @param received_image_path Path to received image file
     * @return Approval test result
     */
    ApprovalTestResult HandleNewTest(const std::string& test_name,
                                   const std::string& received_text_path,
                                   const std::string& received_image_path) const;
    
    /**
     * @brief Handle partial baselines (missing approved files)
     * @param test_name Test identifier
     * @param approved_text_path Path to approved text file
     * @param approved_image_path Path to approved image file
     * @param received_text_path Path to received text file
     * @param received_image_path Path to received image file
     * @return Approval test result
     */
    ApprovalTestResult HandlePartialBaseline(const std::string& test_name,
                                           const std::string& approved_text_path,
                                           const std::string& approved_image_path,
                                           const std::string& received_text_path,
                                           const std::string& received_image_path) const;
    
    /**
     * @brief Compare approved and received artifacts
     * @param test_name Test identifier
     * @param approved_text_path Path to approved text file
     * @param approved_image_path Path to approved image file
     * @param received_text_path Path to received text file
     * @param received_image_path Path to received image file
     * @param formatted_result Formatted text result for comparison
     * @return Approval test result
     */
    ApprovalTestResult CompareArtifacts(const std::string& test_name,
                                      const std::string& approved_text_path,
                                      const std::string& approved_image_path,
                                      const std::string& received_text_path,
                                      const std::string& received_image_path,
                                      const std::string& formatted_result) const;
    
    /**
     * @brief Read content from a text file
     * @param file_path Path to text file
     * @return File content as string
     * @throws std::runtime_error if file cannot be read
     */
    std::string ReadTextFile(const std::string& file_path) const;
    
    /**
     * @brief Write content to a text file
     * @param file_path Path to text file
     * @param content Content to write
     * @return true if file written successfully
     */
    bool WriteTextFile(const std::string& file_path, const std::string& content) const;
};

/**
 * @brief Factory for creating approval test orchestrators
 * 
 * Provides convenient factory methods for creating orchestrators with
 * different configurations and service combinations.
 */
class ApprovalTestOrchestratorFactory {
public:
    /**
     * @brief Create standard approval test orchestrator
     * @return Configured orchestrator with standard services
     */
    static std::unique_ptr<ApprovalTestOrchestrator> CreateStandard();
    
    /**
     * @brief Create fuzzy comparison approval test orchestrator
     * @param image_tolerance Tolerance for image comparison (0.0-1.0)
     * @return Configured orchestrator with fuzzy comparison
     */
    static std::unique_ptr<ApprovalTestOrchestrator> CreateWithFuzzyComparison(double image_tolerance = 0.01);
    
    /**
     * @brief Create compact formatting approval test orchestrator
     * @return Configured orchestrator with compact formatting
     */
    static std::unique_ptr<ApprovalTestOrchestrator> CreateCompact();
};

} // namespace golf_sim::image_analysis::testing
