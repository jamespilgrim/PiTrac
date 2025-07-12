/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file diff_launcher.hpp
 * @brief Service for launching diff tools for approval workflow
 * 
 * Handles launching external diff tools and managing approval workflow.
 * Follows Single Responsibility Principle - only concerned with diff tool management.
 */

#pragma once

#include "approval_test_config.hpp"
#include <string>
#include <memory>

namespace golf_sim::image_analysis::testing {

/**
 * @brief Information about a diff operation
 */
struct DiffInfo {
    std::string approved_path;
    std::string received_path;
    std::string test_name;
    bool is_new_baseline;
    
    DiffInfo(const std::string& approved, const std::string& received, 
             const std::string& name, bool new_baseline = false)
        : approved_path(approved), received_path(received), 
          test_name(name), is_new_baseline(new_baseline) {}
};

/**
 * @brief Interface for diff launching strategies
 */
class IDiffLauncher {
public:
    virtual ~IDiffLauncher() = default;
    
    /**
     * @brief Launch a text diff tool
     * @param diff_info Information about the diff operation
     * @return true if diff tool was launched successfully
     */
    virtual bool LaunchTextDiff(const DiffInfo& diff_info) const = 0;
    
    /**
     * @brief Launch an image diff tool
     * @param diff_info Information about the diff operation
     * @return true if diff tool was launched successfully
     */
    virtual bool LaunchImageDiff(const DiffInfo& diff_info) const = 0;
    
    /**
     * @brief Check if running in an environment where diff tools should be launched
     * @return true if diff tools should be launched
     */
    virtual bool ShouldLaunchDiff() const = 0;
};

/**
 * @brief VS Code-based diff launcher
 * 
 * Uses VS Code's diff functionality for both text and image comparisons.
 */
class VSCodeDiffLauncher : public IDiffLauncher {
public:
    /**
     * @brief Constructor with dependency injection
     * @param config Configuration for diff launching
     */
    explicit VSCodeDiffLauncher(const ApprovalTestConfig& config);
    
    bool LaunchTextDiff(const DiffInfo& diff_info) const override;
    bool LaunchImageDiff(const DiffInfo& diff_info) const override;
    bool ShouldLaunchDiff() const override;

private:
    const ApprovalTestConfig& config_;
    
    /**
     * @brief Execute a command and return success status
     * @param command Command to execute
     * @return true if command executed successfully
     */
    bool ExecuteCommand(const std::string& command) const;
    
    /**
     * @brief Create empty baseline file for new test comparisons
     * @param baseline_path Path where baseline should be created
     * @param content_type Type of content ("text" or "image")
     * @return true if baseline was created successfully
     */
    bool CreateEmptyBaseline(const std::string& baseline_path, const std::string& content_type) const;
};

/**
 * @brief No-op diff launcher for CI environments
 * 
 * Provides logging but doesn't launch interactive tools in CI environments.
 */
class CIDiffLauncher : public IDiffLauncher {
public:
    bool LaunchTextDiff(const DiffInfo& diff_info) const override;
    bool LaunchImageDiff(const DiffInfo& diff_info) const override;
    bool ShouldLaunchDiff() const override;
};

/**
 * @brief Factory for creating diff launchers
 */
class DiffLauncherFactory {
public:
    enum class LauncherType {
        AUTO_DETECT,  // Automatically choose based on environment
        VSCODE,
        CI_NOOP
    };
    
    static std::unique_ptr<IDiffLauncher> Create(LauncherType type, 
                                               const ApprovalTestConfig& config);
};

} // namespace golf_sim::image_analysis::testing
