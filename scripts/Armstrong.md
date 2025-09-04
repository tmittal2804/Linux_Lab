# ARMSTRONG NUMBER 
An Armstrong number is an integer that is equal to the sum of each of its digits raised to the power of the number of digits. Example: 153 = 1^3 + 5^3 + 3^3.
## Orignal script 
```bash

#!/bin/bash
# armstrong.sh
# Usage: ./Armstrong.sh 153

if [ $# -ne 1 ]; then
  echo "Usage: $0  <non-negative-integer>"
  exit 1
fi

n="$1"
if ! [[ $n =~ ^[0-9]+$ ]]; then
  echo "Input must be a non-negative integer."
  exit 1
fi

# count digits
temp="$n"; digits=0
while [ "$temp" -gt 0 ]; do
  temp=$(( temp / 10 ))
  ((digits++))
done
# handle zero
[ $digits -eq 0 ] && digits=1

sum=0
temp="$n"
while [ "$temp" -gt 0 ]; do
  d=$(( temp % 10 ))
  # compute d^digits
  pow=1
  for ((i=0;i<digits;i++)); do pow=$(( pow * d )); done
  sum=$(( sum + pow ))
  temp=$(( temp / 10 ))
done

if [ "$sum" -eq "$n" ]; then
  echo "$n is an Armstrong number."
else
  echo "$n is NOT an Armstrong number (sum=$sum)."
fi

```
## LINE BY LINE EXPLANATION 

### 1. Shebang 

```bash
#!/bin/bash
```
Tells the Operating system to execute this file with /bin/bash (the Bash shell).

### 2.

```bash
# Armstrong.sh
```
File name or short description for the user

### 3.

```bash
# Usage: ./Armstrong.sh 153
```
Showing the command line to run,Number added after sh file is the number on which the operation will be performed

### 4. 
A line left to improve the readiability of the code, it has no effeect on execution.

### 5.

