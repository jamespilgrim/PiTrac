/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file approval_test_config.hpp
 * @brief Configuration management for approval tests
 * 
 * Centralizes configuration settings and eliminates magic numbers/hardcoded paths.
 * Follows Single Responsibility Principle by handling only configuration concerns.
 */

#pragma once

#include <string>
#include <filesystem>

namespace golf_sim::image_analysis::testing {

/**
 * @brief Configuration settings for approval tests
 * 
 * Encapsulates all configuration data to eliminate magic numbers and 
 * provide a single source of truth for test settings.
 */
class ApprovalTestConfig {
public:
    /**
     * @brief Get the singleton instance of the configuration
     * @return Reference to the configuration instance
     */
    static const ApprovalTestConfig& Instance();

    // Directory paths
    const std::string& GetPiTracImagesDir() const { return pitrac_images_dir_; }
    const std::string& GetApprovalArtifactsDir() const { return approval_artifacts_dir_; }
    
    // Image settings
    int GetDefaultImageWidth() const { return default_image_width_; }
    int GetDefaultImageHeight() const { return default_image_height_; }
    
    // Visualization settings
    const std::string& GetBallDetectionColor() const { return ball_detection_color_; }
    int GetCircleThickness() const { return circle_thickness_; }
    double GetFontScale() const { return font_scale_; }
    int GetTextOffsetX() const { return text_offset_x_; }
    int GetTextOffsetY() const { return text_offset_y_; }
    
    // File extensions
    const std::string& GetTextFileExtension() const { return text_extension_; }
    const std::string& GetImageFileExtension() const { return image_extension_; }
    const std::string& GetReceivedSuffix() const { return received_suffix_; }
    const std::string& GetApprovedSuffix() const { return approved_suffix_; }
    
    // Environment detection
    bool IsRunningInCI() const;
    
    /**
     * @brief Ensure all required directories exist
     * @throws std::runtime_error if directories cannot be created
     */
    void EnsureDirectoriesExist() const;

private:    
    ApprovalTestConfig();
    
    // Directory paths (relative from build directory)
    const std::string pitrac_images_dir_ = "../../../Images/";
    const std::string approval_artifacts_dir_ = "../tests/approval_artifacts/";
    
    // Image dimensions
    const int default_image_width_ = 640;
    const int default_image_height_ = 480;
    
    // Visualization settings
    const std::string ball_detection_color_ = "green";  // Semantic color name
    const int circle_thickness_ = 2;
    const double font_scale_ = 0.5;
    const int text_offset_x_ = 5;
    const int text_offset_y_ = 20;
    
    // File naming
    const std::string text_extension_ = ".txt";
    const std::string image_extension_ = ".png";
    const std::string received_suffix_ = ".received";
    const std::string approved_suffix_ = ".approved";
};

} // namespace golf_sim::image_analysis::testing
