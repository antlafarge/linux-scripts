#!/bin/bash

dir=$1

if [ -z "$dir" ]
then
    dir='.'
fi

for file in "$dir"/*
do
    echo "$file"
    filename="${file%.*}"
    target="$filename.7z"
    7z a -mx=9 -y -bsp0 -bso0 "$target" "$file"
    echo "$target"
    echo ""
done
