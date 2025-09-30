#!/bin/bash
# count_lines_words2.sh
# usage: ./count_lines_words1.sh data.txt

if [ $# -ne 1 ]; then
  echo "usage: $0 <filename>"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "File not found."
  exit 1
fi

lines=$(wc -l < "$1")
words=$(wc -w < "$1")
chars=$(wc -m < "$1")

echo "Lines: $lines"
echo "words: $words"
echo "Characters: $chars"
 
