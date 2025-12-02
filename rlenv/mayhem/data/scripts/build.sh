#!/bin/bash
set -euo pipefail

# RLENV Build Script
# This script rebuilds the application from source located at /rlenv/source/ocean/
#
# Original image: ghcr.io/mayhemheroes/ocean:main
# Git revision: 88f316160970239464c023f44372590eb586e942

# ============================================================================
# Environment Variables
# ============================================================================
# No special environment variables needed for this C project

# ============================================================================
# REQUIRED: Change to Source Directory
# ============================================================================
cd /rlenv/source/ocean/

# ============================================================================
# Clean Previous Build (recommended)
# ============================================================================
# Remove old build artifacts to ensure fresh rebuild
rm -f bin/pre64 /pre64 2>/dev/null || true
rm -f bin/*.o 2>/dev/null || true

# ============================================================================
# Build Commands (NO NETWORK, NO PACKAGE INSTALLATION)
# ============================================================================
# Ensure bin directory exists
mkdir -p bin

# Build the pre64 binary using the Makefile
make pre

# ============================================================================
# Copy Artifacts (use 'cat >' for busybox compatibility)
# ============================================================================
# Copy the built binary to the expected location
# Using 'cat >' instead of 'cp' for busybox compatibility
cat bin/pre64 > /pre64

# ============================================================================
# Set Permissions
# ============================================================================
chmod 777 /pre64 2>/dev/null || true

# 777 allows validation script (running as UID 1000) to overwrite during rebuild
# 2>/dev/null || true prevents errors if chmod not available

# ============================================================================
# REQUIRED: Verify Build Succeeded
# ============================================================================
if [ ! -f /pre64 ]; then
    echo "Error: Build artifact not found at /pre64"
    exit 1
fi

# Verify executable bit
if [ ! -x /pre64 ]; then
    echo "Warning: Build artifact is not executable"
fi

# Verify file size
SIZE=$(stat -c%s /pre64 2>/dev/null || stat -f%z /pre64 2>/dev/null || echo 0)
if [ "$SIZE" -lt 1000 ]; then
    echo "Warning: Build artifact is suspiciously small ($SIZE bytes)"
fi

echo "Build completed successfully: /pre64 ($SIZE bytes)"
