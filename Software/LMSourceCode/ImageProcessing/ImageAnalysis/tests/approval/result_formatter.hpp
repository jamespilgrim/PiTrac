/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2025, Verdant Consultants, LLC.
 */

/**
 * @file result_formatter.hpp
 * @brief Strategy pattern for formatting analysis results
 * 
 * Provides different formatting strategies for analysis results.
 * Follows Open/Closed Principle - new formatters can be added without modifying existing code.
 */

#pragma once

#include "../../domain/analysis_results.hpp"
#include <string>
#include <memory>

namespace golf_sim::image_analysis::testing {

/**
 * @brief Abstract base class for result formatting strategies
 */
class IResultFormatter {
public:
    virtual ~IResultFormatter() = default;
    
    /**
     * @brief Format a TeedBallResult for approval testing
     * @param result The analysis result to format
     * @return Formatted string representation
     */
    virtual std::string FormatTeedBallResult(const domain::TeedBallResult& result) const = 0;
    
    /**
     * @brief Format a MovementResult for approval testing
     * @param result The movement analysis result to format
     * @return Formatted string representation
     */
    virtual std::string FormatMovementResult(const domain::MovementResult& result) const = 0;
};

/**
 * @brief Standard formatter for approval tests
 * 
 * Provides comprehensive, human-readable formatting suitable for approval testing.
 */
class StandardApprovalFormatter : public IResultFormatter {
public:
    std::string FormatTeedBallResult(const domain::TeedBallResult& result) const override;
    std::string FormatMovementResult(const domain::MovementResult& result) const override;

private:
    std::string FormatBallState(domain::BallState state) const;
    std::string FormatConfidenceLevel(domain::ConfidenceLevel level) const;
    std::string FormatBallPosition(const domain::BallPosition& position) const;
    std::string FormatDebugInfo(const std::vector<std::string>& debug_info) const;
};

/**
 * @brief Compact formatter for minimal output
 * 
 * Alternative formatter that produces concise output for specific test scenarios.
 */
class CompactFormatter : public IResultFormatter {
public:
    std::string FormatTeedBallResult(const domain::TeedBallResult& result) const override;
    std::string FormatMovementResult(const domain::MovementResult& result) const override;
};

/**
 * @brief Factory for creating result formatters
 */
class ResultFormatterFactory {
public:
    enum class FormatterType {
        STANDARD_APPROVAL,
        COMPACT
    };
    
    static std::unique_ptr<IResultFormatter> Create(FormatterType type);
};

} // namespace golf_sim::image_analysis::testing
