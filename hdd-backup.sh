#!/bin/bash

# Usage :
# sudo ./backup-hdd.sh /dev/from /dev/to

sourceDevice=$1
sourcePath="/mnt/TMP_$(cat /proc/sys/kernel/random/uuid)"
destDevice=$2
destPath="/mnt/TMP_$(cat /proc/sys/kernel/random/uuid)"

echo "Backup files"
echo "Source device : $sourceDevice"
echo "Source temp directory : $sourcePath"
echo "Destination device : $destDevice"
echo "Destination temp directory : $destPath"

sudo mkdir "$sourcePath"
sudo mkdir "$destPath"
sudo mount -o ro "$sourceDevice" "$sourcePath"
sudo mount -o rw "$destDevice" "$destPath"
sudo rsync -avhP "$sourcePath/" "$destPath/"
sudo umount "$destDevice"
sudo umount "$sourceDevice"
if [ $? -eq "0" ]
then
	sudo rm -rf "$sourcePath"
	sudo rm -rf "$destPath"
fi

echo "Backup finished!"
