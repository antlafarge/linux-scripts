#!/bin/bash

# Example : sudo ./nas-decrease-devices-count.sh /dev/md0 4

devicePath=$1
echo "devicePath=$devicePath"

dum=$(sudo dumpe2fs -h /dev/md0)
det=$(sudo mdadm --detail $devicePath)

raidLevel=$(echo "$det" | grep "Raid Level" | cut -d" " -f12 | cut -d"d" -f2)
echo "raidLevel=$raidLevel"

chunkSizeK=$(echo "$det" | grep "Chunk Size" | cut -d" " -f12 | cut -d"K" -f1)
echo "chunkSizeK=${chunkSizeK}K"

arraySizeK=$(echo "$det" | grep "Array Size" | cut -d" " -f12)
echo "arraySizeK=${arraySizeK}K ($(($arraySizeK / 1024 / 1024))G)"

usedDevSizeK=$(echo "$det" | grep "Used Dev Size" | cut -d" " -f10)
echo "usedDevSizeK=${usedDevSizeK}K ($(($usedDevSizeK / 1024 / 1024))G)"

raidDevices=$(echo "$det" | grep "Raid Devices" | cut -d" " -f10)
echo "raidDevices=$raidDevices"

wantedDevices=$2
echo "wantedDevices=$wantedDevices"

if [ "$raidLevel" = "5" ]
then
    devicesForIntegrityCount=1
elif [ "$raidLevel" = "6" ]
then
    devicesForIntegrityCount=2
else
    echo "bad raid level"
    exit 1
fi
echo "devicesForIntegrityCount=$devicesForIntegrityCount"

newArraySizeK=$((($wantedDevices - $devicesForIntegrityCount) * $usedDevSizeK))
echo "newArraySizeK=${newArraySizeK}K ($(($newArraySizeK / 1024 / 1024))G)"
echo "Command you may run : sudo resize2fs $devicePath ${newArraySizeK}K"

blockSize=$(echo "$dum" | grep "Block size" | cut -d":" -f2 | cut -d" " -f16)
echo "blockSize=${blockSize}K"

blockCount=$(echo "$dum" | grep "Block count" | cut -d":" -f2 | cut -d" " -f15)
echo "blockCount=${blockCount}K"

arraySizeFromBlocksK=$(($blockCount * $blockSize / 1024))
echo "arraySizeFromBlocksK=${arraySizeFromBlocksK}K ($(($arraySizeFromBlocksK / 1024 / 1024))G)"
echo "Command you may run : sudo resize2fs $devicePath ${arraySizeFromBlocksK}K"
echo "Command you may run : sudo mdadm --grow $devicePath --array-size ${arraySizeFromBlocksK}"
echo "Command you may run : sudo mdadm --grow $devicePath --level=$raidLevel --raid-devices=$wantedDevices" --backup-file "/var/tmp/md0-backup"
echo "Use these commands at your own risks!"
