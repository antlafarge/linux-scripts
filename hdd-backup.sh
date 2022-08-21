#!/bin/bash

# Usage : sudo ./backup-hdd.sh /source /destination
# Example : sudo ./backup-hdd.sh /home/data "/mnt/hdd/backups/backup 1"
# Example : sudo ./backup-hdd.sh /dev/sda1 /dev/sdb1

source=$1
dest=$2

echo "Backup files"
echo "Source : $source"

if [[ $source == /dev/* ]]
then
    sourceMount=true
    sourcePath="/mnt/TMP_$(cat /proc/sys/kernel/random/uuid)"
    echo "Source temp directory : $sourcePath"
else
    sourceMount=false
    sourcePath="$source"
fi

echo "Destination : $dest"

if [[ $dest == /dev/* ]]
then
    destMount=true
    destPath="/mnt/TMP_$(cat /proc/sys/kernel/random/uuid)"
    echo "Destination temp directory : $destPath"
else
    destMount=false
    destPath="$dest"
fi

echo "Do you want to proceed? (y/N) "

read proceed

if [[ "$proceed" == y || "$proceed" == Y ]]
then
    if [[ $sourceMount == true ]]
    then
        sudo mkdir "$sourcePath"
        sudo mount -o ro "$source" "$sourcePath"
    fi
    sudo mkdir -p "$destPath"
    if [[ $destMount == true ]]
    then
        sudo mount -o rw "$dest" "$destPath"
    fi
    sudo rsync -avhP "$sourcePath/" "$destPath/"
    if [[ $sourceMount == true ]]
    then
        sudo umount "$source"
        if [[ $? == 0 ]]
        then
            sudo rm -rf "$sourcePath"
            echo "rm"
        fi
    fi
    if [[ $destMount == true ]]
    then
        sudo umount "$dest"
        if [[ $? == 0 ]]
        then
            sudo rm -rf "$destPath"
            echo "rm"
        fi
    fi
    echo "Backup finished"
else
    echo "Backup canceled"
fi
