#!/usr/bin/env python3

import sys
import subprocess
import os
from pathlib import Path


def check_dependencies():
    try:
        import pytest
        import httpx
        import websocket
        return True
    except ImportError:
        return False


def install_dependencies():
    print("Installing test dependencies...")
    subprocess.run([
        sys.executable, "-m", "pip", "install", 
        "-r", "requirements-test.txt"
    ], check=True)


def run_tests(args=None):
    if args is None:
        args = []
    
    os.environ["TESTING"] = "true"
    
    cmd = [sys.executable, "-m", "pytest"]
    
    if not args:
        cmd.extend([
            "-v",                    # Verbose
            "--tb=short",           # Short traceback
            "--color=yes",          # Colored output
            "-x",                   # Stop on first failure
            "--cov=.",              # Coverage
            "--cov-report=term-missing",  # Show missing lines
        ])
    else:
        cmd.extend(args)
    
    result = subprocess.run(cmd)
    return result.returncode


def main():
    """Main entry point"""
    print("=" * 60)
    print("PiTrac Web Server Test Suite")
    print("=" * 60)
    print()
    
    if not check_dependencies():
        print("Test dependencies not found.")
        response = input("Install them? (y/n): ")
        if response.lower() == 'y':
            install_dependencies()
        else:
            print("Cannot run tests without dependencies.")
            return 1
    
    args = sys.argv[1:]
    
    if "--ci" in args:
        args = ["--quiet", "--tb=short", "--no-header"]
    elif "--quick" in args:
        args = ["-m", "unit", "-v"]
    elif "--full" in args:
        args = ["-v", "--cov=.", "--cov-report=html", "--cov-report=term"]
    elif "--watch" in args:
        try:
            subprocess.run(["pytest-watch", "--clear", "--wait"])
            return 0
        except FileNotFoundError:
            print("pytest-watch not installed. Install with: pip install pytest-watch")
            return 1
    
    print("Running tests...")
    print("-" * 60)
    return run_tests(args)


if __name__ == "__main__":
    sys.exit(main())