### Assessment 1

##### write a program or shell script that processes two arrays — one containing strings or numbers (Array A) and another containing integers (Array B). The program should identify palindromes in the first array and prime numbers in the second array, then generate two specific outputs.
- Problem Description :
1) Given two arrays:
    Array A: Contains a list of numbers or strings.
   Array B: Contains a list of integers.
2) Your program must:
Step 1: Identify the positions (indices) of all palindromic elements in Array A.
A palindrome is a string or number that reads the same backward as forward (e.g., 121, madam, 454).
Step 2: Identify all prime numbers in Array B.
A prime number is a number greater than 1 that has no divisors other than 1 and itself.
Step 3: For each palindrome found in Array A, calculate the sum of its digits (if numeric) or ASCII values (if string).
Then multiply this sum with each prime number found in Array B.
Step 4: Output two new arrays:
Array C: Contains the positions (indices) of palindromes in Array A.
Array D: Contains the product of each palindrome’s digit sum with every prime number in Array

##### Bash script is as follows:

```bash
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
```

##### Line By Line Explanation

1. #!/bin/bash
-  Declares the script should run under the Bash shell.

2. echo "Enter values for Array A (strings or numbers):"
-  Prints a prompt asking the user to enter values for Array A.

3. read -a A
-  Reads space-separated input from the user into the Bash array A.

4. "Enter values for Array B (only numbers):"
Prints a prompt asking the user to enter values for Array B.

5. read -a B
-  Reads space-separated input into the Bash array B.

6. C=()
-  Creates an empty array C to hold indices of palindromes found in A.

7. primes=()
-  Creates an empty array primes to store prime numbers found in B.

8. D=()
-  Creates an empty array D to store final multiplication results.

9. for i in "${!A[@]}"
-  Starts a loop over the indices of array A. ${!A[@]} expands to all indices.

10. str="${A[$i]}"
-  Assigns the element at index i of A to variable str.

11. rev=$(echo "$str" | rev)
-  Reverses the string str using the rev command and stores the reversed value in rev.

12. if [ "$str" = "$rev" ] … C+=("$i")
-  Compares str with its reverse. If equal, the element is a palindrome and its index i is appended to array C.

13. for num in "${B[@]}"
-  Starts a loop over each value num in array B.

14. if [ $num -le 1 ] … continue
-  Skips numbers less than or equal to 1 since they are not prime.

15. prime=true
-  Assumes num is prime until shown otherwise.

16. for ((j=2; j<num; j++))
-  Loops j from 2 up to num-1 to test divisibility.

17. if [ $((num % j)) -eq 0 ] … prime=false; break
-  If num is divisible by j, mark it not prime and exit the inner loop early.

18. if [ "$prime" = true ] … primes+=("$num")
-  If the flag remained true after testing, append num to array primes.

19. for idx in "${C[@]}"
-  Starts a loop over each palindrome index stored in C.

20. item="${A[$idx]}"
-  Fetches the palindrome value from A at index idx into item.

21. sum=0
-  Initializes sum to zero for accumulating digits or ASCII values.

22. if [[ $item =~ ^[0-9]+$ ]]
-  Tests whether item contains only digits (numeric palindrome).

23. Numeric branch: loop over digits, digit=${item:$k:1} then sum=$((sum + digit))
- Iterates through each character of the numeric string, converts to a digit, adds it to sum.

24. String branch: loop over characters, char=${item:$k:1} then ascii=$(printf "%d" "'$char") and sum=$((sum + ascii))
-  For non-numeric palindromes, extract each character, convert to ASCII code using printf, and add that code to sum.

25. for p in "${primes[@]}" … D+=($((sum * p)))
-  For each prime in primes, multiply the computed sum by the prime p and append the product to array D.

26. echo "Palindrome indices (Array C): ${C[@]}"
-  Prints the list of palindrome indices found in A.

27. echo "Prime numbers: ${primes[@]}"
-  Prints the prime numbers found in B.

28. echo "Final results (Array D): ${D[@]}"
-  Prints all multiplication results stored in D.

##### Output:
![Image](./images/4.png)
