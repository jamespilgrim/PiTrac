/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file image_analysis_service.hpp
 * @brief Application service for image analysis operations
 * 
 * High-level service that orchestrates image analysis operations,
 * manages analyzer selection, and handles cross-cutting concerns
 * like logging, caching, and error handling.
 */

#pragma once

#include "../domain/interfaces.hpp"
#include "../domain/analysis_results.hpp"
#include <memory>
#include <map>

namespace golf_sim::image_analysis::application {

    /**
     * @brief Configuration for analyzer selection and behavior
     */
    struct AnalyzerConfig {
        std::string type = "opencv";           // "opencv", "yolo", "tensorflow_lite", etc.
        std::map<std::string, std::string> parameters;
        bool enable_debug_output = false;
        std::string model_path;               // For ML-based analyzers
        double confidence_threshold = 0.5;
        double nms_threshold = 0.4;          // For ML analyzers
        int input_width = 640;               // For ML analyzers  
        int input_height = 640;              // For ML analyzers
        bool gpu_acceleration = false;       // For ML analyzers
    };

    /**
     * @brief Configuration for the image analysis service
     */
    struct ServiceConfig {
        std::string default_analyzer_type = "opencv";
        double default_confidence_threshold = 0.5;
        bool enable_debug_logging = false;
        bool enable_result_caching = true;
        bool enable_result_storage = false;
        std::string model_path;  // For ML-based analyzers
        
        // Performance settings
        bool enable_parallel_processing = true;
        int max_worker_threads = 4;
        
        // Quality settings
        bool enable_result_validation = true;
        double min_acceptable_confidence = 0.3;
    };    /**
     * @brief Main application service for image analysis
     * 
     * Provides a high-level interface for image analysis operations
     * with configuration management, error handling, and logging.
     */
    class ImageAnalysisService {
    public:
        ImageAnalysisService(
            std::unique_ptr<domain::IImageAnalyzerFactory> factory,
            std::unique_ptr<domain::IAnalyzerConfigRepository> config_repo = nullptr,
            std::unique_ptr<domain::IAnalysisResultRepository> result_repo = nullptr
        );
        
        ~ImageAnalysisService() = default;
          // Configuration management
        [[nodiscard]] bool Configure(const AnalyzerConfig& config);
        [[nodiscard]] AnalyzerConfig GetCurrentConfig() const { return current_analyzer_config_; }
        [[nodiscard]] bool IsConfigured() const { return is_configured_; }
        
        // Analyzer management
        [[nodiscard]] bool SetAnalyzerType(const std::string& analyzer_type);
        [[nodiscard]] std::string GetCurrentAnalyzerType() const;
        [[nodiscard]] std::vector<std::string> GetAvailableAnalyzers() const;
        [[nodiscard]] std::string GetCurrentAnalyzerInfo() const;

        // Main analysis operations - delegate to configured analyzer
        [[nodiscard]] domain::TeedBallResult AnalyzeTeedBall(
            const domain::ImageBuffer& image,
            const std::optional<domain::BallPosition>& expected_position = std::nullopt
        );
        
        [[nodiscard]] domain::MovementResult DetectMovement(
            const std::vector<domain::ImageBuffer>& image_sequence,
            const domain::BallPosition& reference_ball_position
        );
        
        [[nodiscard]] domain::FlightAnalysisResult AnalyzeBallFlight(
            const domain::ImageBuffer& strobed_image,
            const domain::BallPosition& calibration_reference
        );
        
        [[nodiscard]] domain::TeedBallResult DetectBallReset(
            const domain::ImageBuffer& current_image,
            const domain::BallPosition& previous_ball_position
        );
        
        // Service-level operations
        void SetConfidenceThreshold(double threshold);
        void SetDebugMode(bool enabled);
        void ClearResultCache();
        
        // Performance and diagnostics
        struct ServiceStats {
            size_t total_operations = 0;
            size_t successful_operations = 0;
            size_t failed_operations = 0;
            std::chrono::milliseconds total_processing_time{0};
            std::chrono::milliseconds average_processing_time{0};        };
        
        [[nodiscard]] ServiceStats GetServiceStats() const { return stats_; }
        void ResetServiceStats();private:
        // Dependencies
        std::unique_ptr<domain::IImageAnalyzerFactory> factory_;
        std::unique_ptr<domain::IAnalyzerConfigRepository> config_repo_;
        std::unique_ptr<domain::IAnalysisResultRepository> result_repo_;
        
        // Current state
        std::unique_ptr<domain::IImageAnalyzer> current_analyzer_;
        ServiceConfig service_config_;
        AnalyzerConfig current_analyzer_config_;
        bool is_configured_ = false;
        
        // Performance tracking
        mutable ServiceStats stats_;
        
        // Result caching (optional optimization)
        struct CacheKey {
            size_t image_hash;
            std::string operation_type;
            std::string analyzer_type;
            
            bool operator<(const CacheKey& other) const {
                return std::tie(image_hash, operation_type, analyzer_type) <
                       std::tie(other.image_hash, other.operation_type, other.analyzer_type);
            }
        };
        
        mutable std::map<CacheKey, std::string> result_cache_;  // JSON serialized results
          // Helper methods
        bool InitializeAnalyzer();
        void UpdateStats(bool success, std::chrono::milliseconds processing_time) const;
        void LogOperation(const std::string& operation, bool success, 
                         std::chrono::milliseconds processing_time) const;
        void StoreResultIfEnabled(const std::string& operation, 
                                 const std::string& result_json,
                                 const domain::ImageBuffer& image) const;
        
        // Input validation methods
        void ValidateConfidenceThreshold(double threshold) const;
        void ValidateAnalyzerConfig(const AnalyzerConfig& config) const;
        void ValidateAnalyzerType(const std::string& analyzer_type) const;
        void ValidateServiceConfigured() const;
        
        // Cache helpers
        CacheKey CreateCacheKey(const domain::ImageBuffer& image, 
                               const std::string& operation) const;
        size_t HashImage(const domain::ImageBuffer& image) const;
    };

} // namespace golf_sim::image_analysis::application
