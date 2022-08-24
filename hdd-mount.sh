#!/bin/bash

# Mount or umount a device

lsblk -o +pttype,fstype,partuuid,fsuse%,label

echo ""

read -p "Which partition do you want to (u)mount? (example:/dev/sda1) : /dev/sd" partitionEnd

partitionDeviceName="sd${partitionEnd}"
partitionPath="/dev/${partitionDeviceName}"

mapfile -t deviceInfos < <(lsblk -r -o +partuuid | grep "^$partitionDeviceName")

mountPath=$(echo "$deviceInfos" | cut -d' ' -f7)

if [ -n "$mountPath" ]
then
    umount $partitionPath
    umountExitCode=$?
    if [ $umountExitCode -ne 0 ]
    then
        echo "Error : umount failed: umount exited with code '$umountExitCode'"
        exit $umountExitCode
    fi
    echo "Partition '$partitionPath' has been umounted"
    exit 0
fi

read -p "What is the mount name? (example:/mnt/hdd) : /mnt/" mountPathName

mountPath="/mnt/$mountPathName"

if [ ! -f "$mountPath" ]
then
    mkdir -p $mountPath
fi

mount $partitionPath $mountPath
mountExitCode=$?

if [ $mountExitCode -ne 0 ]
then
    echo "Error : Mount failed : mount exited with code ''"
    exit 1
fi

echo "Partition '$partitionPath' mounted here : '$mountPath'"

read -p "Activate auto mount? (y/N) : " res
res="${res,,}" # To lowercase

if [ "$res" == "y" ] || [ "$res" == "yes" ]
then
    partuuid=$(echo "$deviceInfos" | cut -d' ' -f8)
    echo "PARTUUID=$partuuid $targetMountPath    auto    defaults    0    0" >> /etc/fstab
    echo "Auto mount in /etc/fstab added"
fi
