#!/bin/bash

# Script to include .env file in the app bundle
# Add this as a Run Script Build Phase in Xcode, before "Copy Bundle Resources"

# Print environment information for debugging
echo "Running include_env.sh script"
echo "Current directory: $(pwd)"
echo "SRCROOT: $SRCROOT"
echo "BUILT_PRODUCTS_DIR: $BUILT_PRODUCTS_DIR"
echo "PRODUCT_NAME: $PRODUCT_NAME"

# Set paths with fallbacks for CI environments
SRCROOT="${SRCROOT:-$(pwd)}"
BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR:-/Volumes/workspace/build}"
PRODUCT_NAME="${PRODUCT_NAME:-emoji-map}"

ENV_FILE="$SRCROOT/.env"
TARGET_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

echo "Using ENV_FILE: $ENV_FILE"
echo "Using TARGET_DIR: $TARGET_DIR"

# Create the target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
  echo "Creating target directory: $TARGET_DIR"
  mkdir -p "$TARGET_DIR" || {
    echo "Warning: Failed to create target directory, but continuing anyway"
  }
fi

# Check if we're running in a CI environment
if [ -n "$CI" ] || [ -n "$CI_XCODE_CLOUD" ] || [ -d "/Volumes/workspace" ]; then
  echo "Detected CI environment"
  
  # Check if GOOGLE_PLACES_API_KEY environment variable is set
  if [ -n "$GOOGLE_PLACES_API_KEY" ]; then
    echo "Using GOOGLE_PLACES_API_KEY from environment variables"
    
    # Try to create the .env file, but don't fail if we can't
    if touch "$TARGET_DIR/.env" 2>/dev/null; then
      echo "GOOGLE_PLACES_API_KEY=$GOOGLE_PLACES_API_KEY" > "$TARGET_DIR/.env"
      echo "Successfully created .env file in app bundle"
    else
      echo "Warning: Could not create .env file in $TARGET_DIR, but continuing anyway"
    fi
  else
    echo "Warning: GOOGLE_PLACES_API_KEY environment variable not set in CI"
    echo "App will run in mock mode"
  fi
  
  # Always exit successfully in CI to prevent build failures
  exit 0
fi

# For local builds, check if .env file exists
if [ -f "$ENV_FILE" ]; then
  echo "Found .env file at $ENV_FILE"
  
  # Copy the .env file to the app bundle
  if cp "$ENV_FILE" "$TARGET_DIR/.env" 2>/dev/null; then
    echo "Successfully copied .env file to app bundle"
  else
    echo "Warning: Failed to copy .env file to $TARGET_DIR, but continuing anyway"
  fi
else
  echo "Warning: .env file not found at $ENV_FILE"
  
  # Try to create an empty .env file, but don't fail if we can't
  if touch "$TARGET_DIR/.env" 2>/dev/null; then
    echo "Created empty .env file in app bundle for debugging"
  else
    echo "Warning: Could not create empty .env file in $TARGET_DIR, but continuing anyway"
  fi
fi

# Always exit with success to prevent build failures
echo "include_env.sh script completed"
exit 0 