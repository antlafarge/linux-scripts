#!/bin/bash

dir=$1

if [ -z "$dir" ]
then
    echo "Missing dir as argument"
    exit 1
fi

for file in "$dir"/*
do
    echo "$file"
    filename="${file%.*}"
    target="$filename.7z"
    echo "$target"
    7z a -mx=9 -y -bsp0 -bso0 "$target" "$file"
    echo ""
done
