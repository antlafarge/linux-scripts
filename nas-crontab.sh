#!/bin/bash

# Usage :
#     ./nas-crontab.sh help
#     ./nas-crontab.sh info
#     ./nas-crontab.sh start
#     ./nas-crontab.sh restart
#     ./nas-crontab.sh stop
#     ./nas-crontab.sh fix
# Run the root crontab :
#     sudo crontab -e
# Add this line to execute the script (every 60 minutes) :
#     MAILTO="[user@email.com]"
#     */60 * * * * /home/[MyUser]/nas-crontab.sh fix
# And customize these variables :
NAS_DEVICE="/dev/md0"
NAS_MOUNTDIR="/mnt/raid"

start()
{
    echo "Get RAID arrays parttypes"
    parttypes=($(lsblk -l -o FSTYPE,UUID | grep -E "linux_raid_member" | cut -d" " -f2 | grep -E "[-0-9A-Fa-f]{36}" | sort -u))
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed : RAID members UUID not found"
        exit $exitCode
    fi

    size=${#parttypes[@]}
    if [ $size -ne 1 ]
    then
        echo "Fix NAS failed : No or Multiple RAID arrays detected"
        echo "Fix NAS failed"
        exit 1
    else
        selected=${parttypes[0]}
    fi

    echo "Get devices linked to the RAID array"
    devices=$(lsblk -l -o PATH,UUID | grep -E "$selected" | cut -d" " -f1 | tr '\n' ' ')
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed : RAID devices not found"
        exit $exitCode
    fi

    echo "Devices : ${devices[@]}"

    echo "Reassamble the RAID array"
    sudo mdadm --assemble --run --force --update=resync $NAS_DEVICE $devices
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed : RAID array assemble failed"
        exit $exitCode
    fi

    echo "Mount the RAID array"
    sudo mount -a
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed : RAID mount failed"
        exit $exitCode
    fi

    startServices

    if [ -z "$containers" ]
    then
        containers=$(docker ps -aq)
    fi
    
    if [ -n "$containers" ]
    then
        echo "Restart docker containers : "
        echo "$containers"
        docker start $containers
    else
        echo "No docker containers to restart"
    fi
}

stop()
{
    echo "Stop service samba"
    sudo service smbd stop

    echo "Stop service minidlna"
    sudo service minidlna stop

    echo "Get running docker containers"
    containers=$(docker ps -q)
    if [ -n "$containers" ]
    then
        echo "Stop all running docker containers :"
        echo "$containers"
        docker stop $containers
    else
        echo "No running docker containers found"
    fi

    echo "Get mount infos"
    mountRes=$(mount | grep "$NAS_DEVICE")

    if [ -n "$mountRes" ]
    then
        echo "Umount the RAID array"
        sudo umount $NAS_DEVICE
    else
        echo "Nothing the umount"
    fi

    echo "Stop mdadm device $NAS_DEVICE"
    sudo mdadm --stop $NAS_DEVICE
}

restart()
{
    stop
    start
}

startServices()
{
    echo "Restart service samba"
    sudo service smbd restart

    echo "Restart service minidlna"
    sudo service minidlna restart
}

info()
{
    echo "COMMAND \"ls -la /dev/sd*\""
    echo "----------"
    ls -la /dev/sd*
    echo "----------"

    echo "COMMAND \"lsblk -o NAME,VENDOR,MODEL,MOUNTPOINT,SIZE,FSUSE%,TYPE,PTTYPE,FSTYPE,LABEL,UUID,PARTTYPE,PARTUUID\""
    echo "----------"
    lsblk -o NAME,VENDOR,MODEL,MOUNTPOINT,SIZE,FSUSE%,TYPE,PTTYPE,FSTYPE,LABEL,UUID,PARTTYPE,PARTUUID
    echo "----------"

    echo "COMMAND \"cat /proc/mdstat\""
    echo "----------"
    cat /proc/mdstat
    echo "----------"

    echo "COMMAND \"sudo mdadm --detail $NAS_DEVICE\""
    echo "----------"
    sudo mdadm --detail $NAS_DEVICE
    echo "----------"
}

fix()
{
    mountRes=$(mount | grep "$NAS_DEVICE")
    arrayState=$(sudo mdadm --detail $NAS_DEVICE | grep "State : " | sed -En "s/.+State : ([^\s]+).+/\1/p")

    if [ -z "$mountRes" ] || [ "$arrayState" != "clean" ]
    then
        echo "Fix NAS"

        info

        restart

        echo "NAS fixed"
    else
        startServices

        echo "NAS OK"
    fi
}

help()
{
    echo "Available parameters :"
    echo "  - help"
    echo "  - info"
    echo "  - start"
    echo "  - restart"
    echo "  - stop"
    echo "  - fix"
}

if [ "$1" = "start" ]
then
    start
elif [ "$1" = "stop" ]
then
    stop
elif [ "$1" = "restart" ]
then
    restart
elif [ "$1" = "fix" ]
then
    fix
elif [ "$1" = "info" ]
then
    info
elif [ "$1" = "help" ]
then
    help
else
    help
fi
