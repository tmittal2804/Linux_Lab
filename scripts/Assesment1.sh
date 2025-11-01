#!/bin/bash

# Taking input from user
echo "Enter values for Array A (strings or numbers):"
read -a A

echo "Enter values for Array B (only numbers):"
read -a B

C=()   # To store palindrome indexes
primes=()
D=()   # To store multiplication results

# Step 1: Find palindrome positions
for i in "${!A[@]}"
do
    str="${A[$i]}"
    rev=$(echo "$str" | rev)

    if [ "$str" = "$rev" ]
    then
        C+=("$i")
    fi
done

# Step 2: Find prime numbers in B
for num in "${B[@]}"
do
    if [ $num -le 1 ]
    then
        continue
    fi

    prime=true
    for ((j=2; j<num; j++))
    do
        if [ $((num % j)) -eq 0 ]
        then
            prime=false
            break
        fi
    done

    if [ "$prime" = true ]
    then
        primes+=("$num")
    fi
done

# Step 3: Sum digits or ASCII and multiply
for idx in "${C[@]}"
do
    item="${A[$idx]}"
    sum=0

    # If numeric palindrome
    if [[ $item =~ ^[0-9]+$ ]]
    then
        for ((k=0; k<${#item}; k++))
        do
            digit=${item:$k:1}
            sum=$((sum + digit))
        done
    else
        # If string palindrome
        for ((k=0; k<${#item}; k++))
        do
            char=${item:$k:1}
            ascii=$(printf "%d" "'$char")
            sum=$((sum + ascii))
        done
    fi

    # Multiply sum with each prime number
    for p in "${primes[@]}"
    do
        D+=($((sum * p)))
    done
done

echo "Palindrome indices (Array C): ${C[@]}"
echo "Prime numbers: ${primes[@]}"
echo "Final results (Array D): ${D[@]}"
