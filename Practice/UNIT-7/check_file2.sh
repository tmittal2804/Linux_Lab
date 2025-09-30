#!/bin/bash
# check_file.sh
# usage: ./check_file.sh filename.txt

if [ $# -ne 1 ]; then 
 echo "usage: $0 <filename>"
 exit 1
fi

file="$1"
if  [ -e "$file" ]; then
 echo "File  exists: $file"
 echo "------contents------"
 cat -- "$file"
else
 echo "File '$file' does not exist."
 read -p "cvreate it now? (y/n) :  " ans
 case "$ans" in 
  [Yy]*) touch "$file"; echo "created $file"; echo  "You can edit it using your favourite editor";;
  *) echo "Not creating file.";;
  esac
fi


