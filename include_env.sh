#!/bin/bash

# Script to include .env file in the app bundle
# Add this as a Run Script Build Phase in Xcode, before "Copy Bundle Resources"

# Set paths
ENV_FILE="$SRCROOT/.env"
TARGET_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

# Check if .env file exists
if [ -f "$ENV_FILE" ]; then
  echo "Including .env file in app bundle"
  
  # Copy the .env file to the app bundle
  cp "$ENV_FILE" "$TARGET_DIR/.env"
  
  echo "Successfully included .env file in app bundle"
else
  echo "Warning: .env file not found at $ENV_FILE"
  echo "Creating empty .env file in app bundle for debugging"
  
  # Create an empty .env file in the app bundle for debugging
  touch "$TARGET_DIR/.env"
fi 