#!/bin/bash

# Input first array
echo "Enter numbers for first array (space separated):"
read -a arr1

# Input second array
echo "Enter numbers for second array (space separated):"
read -a arr2

# --- Find palindromes in first array ---
palindrome_positions=()
sum_of_digits=0
pos=1

for num in "${arr1[@]}"; do
    rev=$(echo $num | rev)
    if [ "$num" -eq "$rev" ]; then
        palindrome_positions+=($pos)
        # Sum of digits
        digits_sum=0
        for (( i=0; i<${#num}; i++ )); do
            digits_sum=$((digits_sum + ${num:i:1}))
        done
        sum_of_digits=$((sum_of_digits + digits_sum))
    fi
    ((pos++))
done

# --- Find product of prime numbers in second array ---
is_prime() {
    n=$1
    if [ "$n" -le 1 ]; then
        return 1
    fi
    for ((i=2; i*i<=n; i++)); do
        if (( n % i == 0 )); then
            return 1
        fi
    done
    return 0
}

product=1
for num in "${arr2[@]}"; do
    if is_prime "$num"; then
        product=$((product * num))
    fi
done

# --- Outputs ---
echo "Positions of palindrome numbers in first array: ${palindrome_positions[@]}"
echo "Sum of digits of palindrome numbers: $sum_of_digits"
echo "Product of prime numbers in second array: $product"
