#!/bin/bash

# Create backup directory if it does not exist
mkdir -p backup

# Get current timestamp
timestamp=$(date +"%Y%m%d_%H%M%S")

# Loop through all .txt files in the current directory
for file in *.txt; do
    # Check if there are .txt files
    if [ -e "$file" ]; then
        # Extract filename without extension
        filename=$(basename "$file" .txt)
        # Copy file to backup with timestamp
        cp "$file" "backup/${filename}_$timestamp.txt"
        echo "Backed up: $file -> backup/${filename}_$timestamp.txt"
    fi
done
