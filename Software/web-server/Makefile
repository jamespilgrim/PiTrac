# PiTrac Web Server Testing Makefile

.PHONY: help install test test-unit test-integration test-websocket test-coverage test-ci clean run dev

help:
	@echo "PiTrac Web Server - Test Commands"
	@echo "================================="
	@echo "make install        - Install all dependencies"
	@echo "make test          - Run all tests"
	@echo "make test-unit     - Run unit tests only"
	@echo "make test-integration - Run integration tests only"
	@echo "make test-websocket - Run WebSocket tests only"
	@echo "make test-coverage - Run tests with coverage report"
	@echo "make test-ci       - Run tests in CI mode (no interaction)"
	@echo "make test-watch    - Run tests in watch mode"
	@echo "make clean         - Clean test artifacts"
	@echo "make run           - Run the web server"
	@echo "make dev           - Run in development mode with auto-reload"

install:
	pip install -r requirements.txt
	pip install -r requirements-test.txt

test:
	pytest -v

test-unit:
	pytest -v -m unit

test-integration:
	pytest -v -m integration

test-websocket:
	pytest -v -m websocket

test-coverage:
	pytest --cov=. --cov-report=html --cov-report=term-missing

test-ci:
	pytest --tb=short --quiet --no-header --no-summary -q

test-watch:
	pytest-watch --clear --wait

clean:
	rm -rf .pytest_cache
	rm -rf htmlcov
	rm -rf .coverage
	rm -rf __pycache__
	rm -rf tests/__pycache__
	find . -type f -name "*.pyc" -delete

run:
	python main.py

dev:
	uvicorn main:app --reload --host 0.0.0.0 --port 8080