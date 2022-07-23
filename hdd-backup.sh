#!/bin/bash

# Usage :
# sudo ./backup-hdd.sh /dev/sdX "/mnt/hdd/Backups/backup 1"

DEV=$1
TMP="/mnt/TMP_$(cat /proc/sys/kernel/random/uuid)"
DEST=$2

echo "Backup files"
echo "Source device : $DEV"
echo "Temp directory : $TMP"
echo "Target directory : $DEST"

sudo mkdir -p "$TMP"
sudo mount -o ro "$DEV" "$TMP"
sudo mkdir -p "$DEST"
sudo rsync -avhP "$TMP/" "$DEST"
sudo umount "$DEV"
sudo rm -rf "$TMP"

echo "Backup finished!"
