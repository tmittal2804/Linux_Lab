#!/bin/bash
# Script to print numbers from start to end with a given step

# Take user inputs
read -p "Enter start value: " start
read -p "Enter end value: " end
read -p "Enter step value: " step

# Validate inputs
if ! [[ "$start" =~ ^-?[0-9]+$ && "$end" =~ ^-?[0-9]+$ && "$step" =~ ^[0-9]+$ ]]; then
    echo "Error: Inputs must be integers, and step must be a positive integer."
    exit 1
fi

if [ "$step" -le 0 ]; then
    echo "Error: Step must be greater than zero."
    exit 1
fi

# Print numbers
echo "Printing numbers from $start to $end with step $step:"
for (( i=$start; i<=$end; i+=$step ))
do
    echo "$i"
done
