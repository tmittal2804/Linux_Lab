#!/bin/bash
# Script: starter_kit.sh
# Purpose: Create a starter project environment with folders and README files

# Create main project directory
mkdir -p project/{scripts,docs,data}

# Add README.md in each folder
echo "# Project Root" > project/README.md
echo "# Scripts Folder" > project/scripts/README.md
echo "# Documentation Folder" > project/docs/README.md
echo "# Data Folder" > project/data/README.md

# Print confirmation message
echo "Starter Kit Ready!"
