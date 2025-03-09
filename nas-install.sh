#!/bin/bash
set -e -u -x

# prerequisites : chmod +x nas-install.sh
# usage : debian : sudo ./nas-install.sh
# usage : alpine : su
# usage : alpine : ./nas-install.sh

# Notes : Script must be run with sudo (su root in alpine)

# VARS

user="MyUsername" # Linux user account name

hddUuid="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" # HDD UUID (to check : lsblk -o NAME,VENDOR,MODEL,MOUNTPOINT,SIZE,FSUSE%,TYPE,PTTYPE,FSTYPE,LABEL,UUID)
hddMountPoint="/hdd"                           # HDD mount point

raidMembersUuid="YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY" # RAID UUID for "linux_raid_members" (to check : lsblk -o NAME,VENDOR,MODEL,MOUNTPOINT,SIZE,FSUSE%,TYPE,PTTYPE,FSTYPE,LABEL,UUID)
raidDevicePoint="/dev/md0"                             # RAID device point
raidMountPoint="/storage"                              # RAID mount point

storagePath="/storage"                           # Storage path
dockerComposeYmlPath="$storagePath/Private/Apps" # Docker compose yml config path

otherPackagesToInstall="lsblk nano curl git"

# SCRIPT

OS=$(cat /etc/os-release | grep "ID=" | sed -En "s/^ID=(.+)$/\1/p")
echo "OS detected : $OS"

if [ ! -d "/home/$user" ]; then
    echo "Home directory not found (/home/$user)"
    echo "Check script variables"
    exit 1
fi

# GROUP users
getent group users || addgroup users
usersGid=$(getent group users | cut -d: -f3)
addgroup $user users

# UPDATE
echo "========"
if [[ "$(read -p "OS and packages update ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    [ "$OS" = "alpine" ] && apk update || apt update
    [ "$OS" = "alpine" ] && apk upgrade --available || apt upgrade -y
    if [ -n "$otherPackagesToInstall" ]; then # if there are other packages to install
        [ "$OS" = "alpine" ] && apk add $otherPackagesToInstall || apt install -y $otherPackagesToInstall
    fi
    [ "$OS" != "alpine" ] && apt autoremove -y
    [ "$OS" != "alpine" ] && apt purge
    echo -e "OS and packages updated"
fi

# SSH
echo "========"
if [[ "$(read -p "Create SSH Key ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    sshDir="/home/$user/.ssh"
    mkdir -m 700 -p /home/$user/.ssh
    file="$sshDir/$user"
    ssh-keygen -o -t ed25519 -C "$user" -f "$file"
    chown "$user:$user" "$file"
    chown "$user:$user" "$file.pub"
    cat "$file.pub" >> "/home/$user/.ssh/authorized_keys"
    echo -e "\tKeys created, get the private key ($file) and add it to your client ssh agent :"
    echo -e "\t\t- ssh-add \"$HOME/.ssh/privateKey\""
    echo -e "\t\t- ssh-add \"C:\\Users\\MyUser\\.ssh\\privateKey\" (don't forget to enable service \"OpenSSH Authentication agent\")"
fi

# HDD
echo "========"
if [[ "$(read -p "Mount HDD ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    if ! $(lsblk -l -o UUID | grep -q "$hddUuid"); then # if HDD UUID not found
        echo -e "\tERROR : HDD UUID not found !!"
        exit 1
    fi

    echo -e "\tCreate mount point '$hddMountPoint'"
    mkdir -p $hddMountPoint
    chown -R root:users $hddMountPoint
    chmod -R 775 $hddMountPoint
    find $hddMountPoint -type d -exec chmod g+s {} \;

    hddFstabLine="UUID=$hddUuid $hddMountPoint auto nofail,auto,defaults,noatime 0 0"

    if ! grep -q "$hddFstabLine" /etc/fstab; then # if not in fstab
        echo -e "\tEnable auto-mount on system startup"
        echo -e "\n$hddFstabLine\n" >> /etc/fstab
    fi

    mount -a

    echo -e "\tHDD mounted"
fi

# RAID
echo "========"
if [[ "$(read -p "Re-assemble and mount RAID array ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    [ "$OS" = "alpine" ] && apk add mdadm || apt install -y mdadm

    raidArraysUuids=$(lsblk -l -o FSTYPE,UUID | grep -E "^linux_raid_member\s+" | cut -d" " -f2 | grep -E "[-0-9A-Fa-f]{36}" | sort -u)
    echo "$raidArraysUuids"

    if [[ ! ${raidArraysUuids[*]} =~ "$raidMembersUuid" ]]; then # if RAID UUID not found
        echo -e "\tERROR : RAID UUID not found !!"
        exit 1
    fi

    raidDevices=$(lsblk -l -o PATH,UUID | grep -E "$raidMembersUuid" | cut -d" " -f1 | tr '\n' ' ')
    echo "$raidDevices"

    if [[ -z "$raidDevices" ]]; then # if no devices
        echo -e "\tERROR : RAID devices not found !!"
        exit 1
    fi

    echo -e "\tAssemble the RAID array : $raidDevices"
    mdadm --assemble --run --force --update=resync $raidDevicePoint $raidDevices
    exitCode=$?
    if [ "$exitCode" -ne 0 ]; then # if assemble failed
        echo "\tERROR: Can't assemble the RAID array !!"
        exit $exitCode
    fi

    if ! mount | grep "$raidMountPoint"; then # if not mounted
        echo -e "\tCreate mount point '$raidMountPoint'"
        mkdir -m 775 -p $raidMountPoint
        chown root:users $raidMountPoint
        find $raidMountPoint -type d -exec chmod g+s {} \;
    fi

    raidFstabLine="$raidDevicePoint $raidMountPoint auto nofail,auto,defaults,noatime 0 0"

    if ! grep -q "$raidFstabLine" /etc/fstab; then # if not in fstab
        echo -e "\tEnable auto-mount on system startup"
        echo -e "\n$raidFstabLine\n" >>/etc/fstab
    fi

    mount -a

    echo -e "\tRAID mounted"
fi

# DOCKER
echo "========"
if [[ "$(read -p "Install Docker ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    # Install Docker
    if ! which docker &>/dev/null; then
        if [ "$OS" = "alpine" ]; then
            apk add docker docker-cli docker-cli-compose
            addgroup $user docker
            service docker start
            rc-update add docker boot
        else
            curl -sSL https://get.docker.com | sh
        fi
    fi
fi

if [[ "$(read -p "Run docker compose files ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    # Start docker containers in new docker group without re-login
    echo -e "\tStart docker compose files from '$dockerComposeYmlPath'"
    for file in $dockerComposeYmlPath/*.yml; do
        if [[ -f "$file" ]]; then
            echo -e "\t\tStart docker compose file '$file'"
            docker compose -f "$file" up -d
        fi
    done
fi

echo "========"
echo "Done"
