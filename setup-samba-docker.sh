#!/bin/bash
set -e -u
# set -x

user=MyUser            # Samba user name
hddMountPoint="/hdd"   # HDD mount point
storagePath="/storage" # Storage path
containerName=samba    # Docker container name

# SAMBA functions
sambaAddOrReplaceFieldValueInSection() {
    section=$1
    field=$2
    value=$3
    file=$4

    startingSectionLine=$(docker exec $containerName grep -Ein -m 1 "^\[$section\]$" $file | cut -d":" -f1)

    if [[ -z "$startingSectionLine" ]]; then # if startingSectionLine is null
        docker exec $containerName sh -c "echo -e '\n[$section]\n\n   $field = $value' >> $file"
    else
        endingSectionLine=$(docker exec $containerName sed "1,${startingSectionLine}g" $file | grep -Ein -m 1 "^\[.+\]$" | cut -d":" -f1)

        if [[ -z "$endingSectionLine" ]]; then # if endingSectionLine is null
            endingSectionLine=$(docker exec $containerName grep -c "" $file)
            insertLine=$endingSectionLine
            ((endingSectionLine += 2))
        else
            insertLine=$endingSectionLine
        fi

        found=$(docker exec $containerName sed -n "$startingSectionLine,${endingSectionLine}s/^\s*$field\s*=/&/p" $file)

        if [[ -z $found ]]; then # if found is null
            docker exec $containerName sed -i "${insertLine}i\   $field = $value\n" $file
        else
            docker exec $containerName sed -i "$startingSectionLine,${endingSectionLine}s/^\s*$field\s*=.*$/   $field = $value/" $file
        fi
    fi

    echo "$file : [$section] $field = $value"
}

sambaAddOrReplaceFieldValueInSection "global" "map to guest" "bad user" "/etc/samba/smb.conf"
sambaAddOrReplaceFieldValueInSection "global" "security" "user" "/etc/samba/smb.conf"
sambaAddOrReplaceFieldValueInSection "global" "guest account" "nobody" "/etc/samba/smb.conf"
sambaAddOrReplaceFieldValueInSection "homes" "read only" "no" "/etc/samba/smb.conf"
sambaAddOrReplaceFieldValueInSection "printers" "browseable" "yes" "/etc/samba/smb.conf"
sambaAddOrReplaceFieldValueInSection "printers" "guest ok" "yes" "/etc/samba/smb.conf"

echo "========"
if [[ "$(read -p "Add HDD root as a Samba share ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
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
if [[ "$(read -p "Add your 'Public', 'Shared' and 'Private' storage directories as Samba shares ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    # Public
    echo -e "\tSetup 'Public' Samba share"
    mkdir -m 777 -p $storagePath/Public
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
    mkdir -m 775 -p $storagePath/Shared
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
    mkdir -m 770 -p $storagePath/Private
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
if [[ "$(read -p "Create a samba user named '$user' ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    read -p "UID ? [1000]" uid
    uidOption=$([ -n "$uid" ] && echo "-u $uid" || echo "")
    docker exec $containerName adduser -D -H $uidOption $user $user
    docker exec $containerName getent group users || docker exec $containerName addgroup users
    docker exec $containerName addgroup $user users
    docker exec -it $containerName smbpasswd -a $user
fi

echo -e "\tSetup finished. Please restart the container"

echo "========"
echo "Done"
