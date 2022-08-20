# This script creates an ext4 partition in disks without partitions and mount not mounted devices in /mnt directory.
# This script DOES NEVER delete partions, directories or files.

letters=(a b c d e f g h i j k l m n o p q r s t u v w x y z)

allMountPaths=()
mapfile -t allMountPaths < <(lsblk -r | cut -d' ' -f7 | grep -v -e '^$')

# Process a device and associated partitions
processDevice()
{
    deviceBaseName=$1

    # Get device informations
    mapfile -t devicesInfos < <(lsblk -o +pttype,fstype,uuid -r | grep "^$deviceBaseName")
    devicesInfosSize=${#devicesInfos[@]}

    if [ $devicesInfosSize -eq 0 ]
    then
        return
    fi

    if [ $devicesInfosSize -lt 2 ]
    then
        echo "$deviceBaseName : create partition"

        partitionType=$(echo "$str" | cut -d' ' -f8)
        if [ -z "$partitionType" ]
        then
            # Create partition table
            parted /dev/$deviceBaseName mklabel gpt
        fi

        fyleSystemType=$(echo "$str" | cut -d' ' -f9)
        if [ -z "$fyleSystemType" ]
        then
            # Create partition
            parted /dev/$deviceBaseName -a optimal mkpart primary 0% 100%
            sleep 1
            # Format partion (ext4)
            mkfs.ext4 /dev/${deviceBaseName}1
        fi

        # Refresh device informations
        mapfile -t devicesInfos < <(lsblk -o +pttype,fstype,uuid -r | grep "^$deviceBaseName")
        devicesInfosSize=${#devicesInfos[@]}
    fi

    first=true
    for str in "${devicesInfos[@]}"
    do
        if [ $first == true ]
        then
            first=false
            continue
        fi

        currentMountPath=$(echo "$str" | cut -d' ' -f7)
        if [ -n "$currentMountPath" ]
        then
            continue
        fi
        
        for letter2 in "${letters[@]}"
        do
            targetMountPath="/mnt/disk_$letter2"

            if [[ ${allMountPaths[*]} =~ $targetMountPath ]]
            then
                continue
            fi

            if [ ! -f "mntPath" ]
            then
                mkdir -p $targetMountPath
            fi

            deviceName=$(echo "$str" | cut -d' ' -f1)
            echo "$deviceName : Mount here '$targetMountPath'"

            device="/dev/$deviceName"
            mount $device $targetMountPath

            if [ $? -ne 0 ]
            then
                echo "$deviceName : Mount here '$targetMountPath' failed"
                allMountPaths+=($targetMountPath)
                continue
            fi

            uuid=$(echo "$str" | cut -d' ' -f10)
            echo "UUID=$uuid $targetMountPath auto defaults 0 0" >> /etc/fstab

            allMountPaths+=($targetMountPath)

            break
        done
    done
}

echo "====================================== INITIAL STATE ======================================="

lsblk -o +pttype,fstype,uuid,fsuse%,label

echo "============================================================================================"

for letter in "${letters[@]}"
do
    processDevice sd$letter
done

echo "======================================= FINAL STATE ========================================"

lsblk -o +pttype,fstype,uuid,fsuse%,label

echo "============================================================================================"
