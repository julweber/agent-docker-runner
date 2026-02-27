#!/bin/bash

# fix_owner.sh - Change ownership of all files in a directory recursively
# Usage: ./fix_owner.sh [directory]

# Default to current directory if no argument provided
TARGET_DIR="${1:-.}"

# Check if directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a valid directory"
    exit 1
fi

# Get the current user
export CALLING_USER=$(whoami)

echo "Changing ownership of all files in '$TARGET_DIR' to '$CALLING_USER'..."

# Use chown -R for recursive ownership change (more efficient)
sudo -E chown -R "$CALLING_USER:" "$TARGET_DIR"

echo "Done. All files are now owned by $CALLING_USER."
