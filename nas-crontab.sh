#!/bin/bash

# Run the root crontab :
#     sudo crontab -e
# Add this line to execute the script (every 60 minutes) :
#     MAILTO="[user@email.com]"
#     */60 * * * * /home/[MyUser]/nas-crontab.sh
# And customize these variables :
NAS_DEVICE="/dev/md0"
NAS_MOUNTDIR="/mnt/raid"

start()
{
    echo "Get raid arrays parttypes"
    parttypes=($(lsblk -l -o FSTYPE,UUID | grep -E "linux_raid_member" | cut -d" " -f2 | grep -E "[-0-9A-Fa-f]{36}"))
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed"
        exit $exitCode
    fi

    parttypes2=()
    
    for item in "${parttypes[@]}"
    do
        if [[ ! ${parttypes2[*]} =~ "$item" ]]
        then
            parttypes2+=($item)
        fi
    done

    size=${#parttypes2[@]}
    if [ $size -gt 1 ]
    then
        echo "Multiple raid arrays detected"
        echo "Fix NAS failed"
        exit 1
    else
        selected=${parttypes2[0]}
    fi

    echo "Get devices linked to the raid array"
    devices=$(lsblk -l -o PATH,UUID | grep -E "$selected" | cut -d" " -f1 | tr '\n' ' ')
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed"
        exit $exitCode
    fi

    echo "Devices : ${devices[@]}"

    echo "Reassamble the raid array"
    sudo mdadm --assemble --run --force --update=resync $NAS_DEVICE $devices
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed"
        exit $exitCode
    fi

    echo "Mount the raid array"
    sudo mount -a
    exitCode=$?
    if [ "$exitCode" -ne 0 ]
    then
        echo "Fix NAS failed"
        exit $exitCode
    fi

    startServices

    if [ -n "$containers" ]
    then
        echo "Restart stopped docker containers : $containers"
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
        echo "Stop all running  docker containers : $containers"
        docker stop $containers
    else
        echo "No running docker containers found"
    fi

    echo "Get mount infos"
    mountRes=$(mount | grep "$NAS_DEVICE")

    if [ -n "$mountRes" ]
    then
        echo "Umount raid array"
        sudo umount $NAS_DEVICE
    else
        echo "Nothing the umount"
    fi

    echo "Stop mdadm device $NAS_DEVICE"
    sudo mdadm --stop $NAS_DEVICE

    echo "Stop mdadm device /dev/md127"
    sudo mdadm --stop /dev/md127
}

restart()
{
    stop
    start
}

startServices()
{
    echo "Restart service samba"
    sudo service smbd start

    echo "Restart service minidlna"
    sudo service minidlna start
}

log()
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

        log

        restart

        echo "NAS fixed"
    else
        startServices

        echo "NAS OK"
    fi
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
else
    fix
fi
