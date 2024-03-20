#!/bin/bash

# Notes : Script must be run with sudo

# VARS

user="MyUsername" # Linux user account name

hddUuid="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" # HDD UUID (to check : lsblk -o NAME,VENDOR,MODEL,MOUNTPOINT,SIZE,FSUSE%,TYPE,PTTYPE,FSTYPE,LABEL,UUID)
hddMountPoint="/hdd" # HDD mount point

raidMembersUuid="YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY" # RAID array members UUID (to check : lsblk -o NAME,VENDOR,MODEL,MOUNTPOINT,SIZE,FSUSE%,TYPE,PTTYPE,FSTYPE,LABEL,UUID)
raidDevicePoint="/dev/md0" # RAID device point
raidMountPoint="/storage" # RAID mount point

storagePath="/storage" # Storage path
dockerComposeYmlPath="$storagePath/Private/Apps" # Docker compose yml config path

otherAppsToInstall="curl git"

# SCRIPT

# UPDATE
echo "========"
read -p "OS and packages update ? (y/N) : " res
if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    apt update
    apt upgrade -y
    apt full-upgrade -y
    if [[ -z $otherAppsToInstall ]]; then # if other apps to install
        apt install -y $otherAppsToInstall
    fi
    apt autoremove -y
    apt purge
    echo -e "OS and packages updated"
fi

# HDD
echo "========"
read -p "Mount HDD ? (y/N) : " res
if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    if ! $(lsblk -l -o UUID | grep -q "$hddUuid"); then # if HDD UUID found
        echo -e "\tERROR : HDD UUID not found !!"
        exit 1
    fi

    echo -e "\tCreate mount point '$hddMountPoint'"
    mkdir -p $hddMountPoint
    chown -R root:users $hddMountPoint
    chmod -R 775 $hddMountPoint
    find $hddMountPoint -type d -exec chmod g+s {} \;
    
    hddFstabLine="UUID=$hddUuid	$hddMountPoint	auto	nofail,auto,defaults,noatime	0	0"

    if ! grep -q "$hddFstabLine" /etc/fstab; then # if not in fstab
        echo -e "\tEnable auto-mount on system startup"
        echo -e "\n$hddFstabLine\n" >> /etc/fstab
    fi

    if ! $(lsblk -l -o UUID,MOUNTPOINT | grep -Eq "$hddUuid\s+$hddMountPoint"); then # if not mounted
        echo -e "\tMount"
        mount UUID=$hddUuid $hddMountPoint
    fi

    echo -e "\tHDD mounted"
fi

# RAID
echo "========"
read -p "Re-assemble and mount RAID array ? (y/N) : " res
if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    apt install -y mdadm

    raidArraysUuids=$(lsblk -l -o FSTYPE,UUID | grep -E "^linux_raid_member\s+" | cut -d" " -f2 | grep -E "[-0-9A-Fa-f]{36}" | sort -u)

    if [[ ! ${raidArraysUuids[*]} =~ "$raidMembersUuid" ]]; then # if RAID UUID not found
        echo -e "\tERROR : RAID UUID not found !!"
        exit 1
    fi

    raidDevices=$(lsblk -l -o PATH,UUID | grep -E "$raidMembersUuid" | cut -d" " -f1 | tr '\n' ' ')

    if [[ -z $raidDevices ]]; then # if no devices
        echo -e "\tERROR : RAID devices not found !!"
        exit 1
    fi

    echo -e "\tAssemble the RAID array : $raidDevices"
    sudo mdadm --assemble --run --force --update=resync $raidDevicePoint $raidDevices
    exitCode=$?
    if [ "$exitCode" -ne 0 ]; then # if assemble failed
        echo "\tERROR: Can't assemble the RAID array !!"
        exit $exitCode
    fi

    echo -e "\tCreate mount point '$raidMountPoint'"
    mkdir -p $raidMountPoint
    chown root:users $raidMountPoint
    chmod 775 $raidMountPoint
    find $raidMountPoint -type d -exec chmod g+s {} \;
    
    raidFstabLine="$raidDevicePoint	$raidMountPoint	auto	nofail,auto,defaults,noatime	0	0"
    
    if ! grep -q "$raidFstabLine" /etc/fstab; then # if not in fstab
        echo -e "\tEnable auto-mount on system startup"
        echo -e "\n$raidFstabLine\n" >> /etc/fstab
    fi

    if ! $(lsblk -l -o UUID,MOUNTPOINT | grep -Eq "$raidDevicePoint\s+$raidMountPoint"); then # if not mounted
        echo -e "\tMount"
        mount $raidDevicePoint $raidMountPoint
    fi

    echo -e "\tRAID mounted"
fi

# SAMBA functions
sambaAddOrReplaceFieldValueInSection()
{
    section=$1
    field=$2
    value=$3
    file=$4

    startingSectionLine=$(grep -Ein -m 1 "^\[$section\]$" $file | cut -d":" -f1)

    if [[ -z $startingSectionLine ]]; then # if startingSectionLine is null
        echo -e "\n[$section]\n\n   $field = $value" >> $file
    else
        endingSectionLine=$(sed "1,${startingSectionLine}g" $file | grep -Ein -m 1 "^\[.+\]$" | cut -d":" -f1)

        if [[ -z $endingSectionLine ]]; then # if endingSectionLine is null
            endingSectionLine=$(grep -c "" $file)
            insertLine=$endingSectionLine
            ((endingSectionLine+=2))
        else
            insertLine=$endingSectionLine
        fi
        
        found=$(sed -n "$startingSectionLine,${endingSectionLine}s/^\s*$field\s*=/&/p" $file)

        if [[ -z $found ]]; then # if found is null
            sed -i "${insertLine}i\   $field = $value\n" $file
        else
            sed -i "$startingSectionLine,${endingSectionLine}s/^\s*$field\s*=.*$/   $field = $value/" $file
        fi
    fi

    echo "$file : [$section] $field = $value"
}

# SAMBA
echo "========"
read -p "Install and configure Samba ? (y/N) : " res
if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    apt install -y samba
    sambaAddOrReplaceFieldValueInSection "global" "map to guest" "bad user" "/etc/samba/smb.conf"
    sambaAddOrReplaceFieldValueInSection "global" "security" "user" "/etc/samba/smb.conf"
    sambaAddOrReplaceFieldValueInSection "global" "guest account" "nobody" "/etc/samba/smb.conf"
    sambaAddOrReplaceFieldValueInSection "homes" "read only" "no" "/etc/samba/smb.conf"
    sambaAddOrReplaceFieldValueInSection "printers" "browseable" "yes" "/etc/samba/smb.conf"
    sambaAddOrReplaceFieldValueInSection "printers" "guest ok" "yes" "/etc/samba/smb.conf"

    echo "========"
    read -p "Add HDD root as a Samba share ? (y/N) : " res
    if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
        sambaAddOrReplaceFieldValueInSection "HDD" "comment" "HDD storage" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "path" "$hddMountPoint" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "browseable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "public" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "guest ok" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "guest only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "read only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "writable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "create mask" "0777" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "directory mask" "0777" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "force create mode" "0777" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "HDD" "force directory mode" "0777" "/etc/samba/smb.conf"
    fi

    echo "========"
    read -p "Add your 'Public', 'Shared' and 'Private' storage directories as Samba shares ? (y/N) : " res
    if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
        # Public
        echo -e "\tSetup 'Public' Samba share"
        mkdir -p $storagePath/Public
        chown -R root:users $storagePath/Public
        chmod -R 777 $storagePath/Public
        find $storagePath/Public -type d -exec chmod g+s {} \;
        sambaAddOrReplaceFieldValueInSection "Public" "comment" "Public storage" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "path" "$storagePath/Public" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "browseable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "public" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "guest ok" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "guest only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "read only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "writable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "create mask" "0777" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "directory mask" "0777" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "force create mode" "0777" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Public" "force directory mode" "0777" "/etc/samba/smb.conf"
        
        # Shared
        echo -e "\tSetup 'Shared' Samba share"
        mkdir -p $storagePath/Shared
        chown -R root:users $storagePath/Shared
        chmod -R 775 $storagePath/Shared
        find $storagePath/Shared -type d -exec chmod g+s {} \;
        sambaAddOrReplaceFieldValueInSection "Shared" "comment" "Shared storage" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "path" "$storagePath/Shared" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "browseable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "public" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "guest ok" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "guest only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "read only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "writable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "write list" "@users" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "create mask" "0775" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "directory mask" "0775" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "force create mode" "0775" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Shared" "force directory mode" "0775" "/etc/samba/smb.conf"
        
        # Private
        echo -e "\tSetup 'Private' Samba share"
        mkdir -p $storagePath/Private
        chown root:users $storagePath/Private
        chmod -R 770 $storagePath/Private
        find $storagePath/Private -type d -exec chmod g-s {} \;
        sambaAddOrReplaceFieldValueInSection "Private" "comment" "Private storage" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "path" "$storagePath/Private" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "browseable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "public" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "guest ok" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "guest only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "read only" "no" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "writable" "yes" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "write list" "@users" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "read list" "@users" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "create mask" "0770" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "directory mask" "0770" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "force create mode" "0770" "/etc/samba/smb.conf"
        sambaAddOrReplaceFieldValueInSection "Private" "force directory mode" "0770" "/etc/samba/smb.conf"
    fi
    
    echo "========"
    read -p "Create a samba user named '$user' ? (y/N) : " res
    if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
        smbpasswd -a $user
    fi

    echo -e "\tRestart service Samba"
    service smbd restart
fi

# DLNA functions
minidlnaConfPathReplacement()
{
    type=$1 # "V" or "A" or "P"
    pathToSet=$2
    file=$3

    if ! grep -Eq "^media_dir=$type,$pathToSet$" $file; then # if the directory is different
        sed -i "s|^media_dir=$type,.*$|media_dir=$type,$pathToSet|" $file # delimiter is | to avoid slahes escape
    fi

    echo "media_dir=$type,$pathToSet"
}

# DLNA
echo "========"
read -p "Install and configure minidlna ? (y/N) : " res
if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    apt install -y minidlna
    
    usermod -aG users minidlna

    echo -e "Add shared directories to minidlna config '/etc/minidlna.conf'"
    minidlnaConfPathReplacement "V" "$storagePath/Shared/Videos" "/etc/minidlna.conf"
    minidlnaConfPathReplacement "A" "$storagePath/Shared/Audio" "/etc/minidlna.conf"
    minidlnaConfPathReplacement "P" "$storagePath/Shared/Pictures" "/etc/minidlna.conf"

    echo -e "\tRestart minidlna"
    service minidlna restart
fi

# DOCKER
echo "========"
read -p "Install Docker and run Docker compose ? (y/N) : " res
if [[ "$res" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    # Install Docker
    if ! dpkg -s docker-ce &> /dev/null; then
        curl -sSL https://get.docker.com | sh
    fi

    usermod -aG docker $user

    # Start docker containers in new docker group without re-login
    echo -e "\tStart docker compose from '$dockerComposeYmlPath'"
    sg docker -c "cd '$dockerComposeYmlPath' && docker compose up -d"
fi

echo "========"
echo "Done"
