#!/bin/bash

# Script to create files with random numbers and print their contents
# Author: GitHub Copilot
# Date: July 25, 2025

echo "Creating files with random numbers..."

# Create a temporary directory for our files
TEMP_DIR="/tmp/random_files_$$"
mkdir -p "$TEMP_DIR"

# Number of files to create
NUM_FILES=5

# Array to store file names
FILE_NAMES=()

# Create files with random numbers
for i in $(seq 1 $NUM_FILES); do
    FILE_NAME="$TEMP_DIR/random_file_$i.txt"
    FILE_NAMES+=("$FILE_NAME")
    
    # Generate 10 random numbers and write to file
    echo "Creating file: $(basename "$FILE_NAME")"
    for j in $(seq 1 10); do
        RANDOM_NUM=$RANDOM
        echo "$RANDOM_NUM" >> "$FILE_NAME"
    done
done

echo ""
echo "Files created successfully!"
echo "Directory: $TEMP_DIR"
echo ""

# Print contents of each file
echo "Printing contents of all files:"
echo "================================"

for file in "${FILE_NAMES[@]}"; do
    echo ""
    echo "Contents of $(basename "$file"):"
    echo "--------------------------------"
    cat "$file"
    echo ""
done

# Clean up option
echo "Would you like to clean up the temporary files? (y/n)"
read -r CLEANUP_CHOICE

if [[ "$CLEANUP_CHOICE" =~ ^[Yy]$ ]]; then
    rm -rf "$TEMP_DIR"
    echo "Temporary files cleaned up."
else
    echo "Temporary files preserved in: $TEMP_DIR"
fi

echo "Script completed successfully!"
