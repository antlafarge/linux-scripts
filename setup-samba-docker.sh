#!/bin/bash
set -e -u
# set -x

user=MyUser            # Samba user name
uid=1000               # User UID
hddMountPoint="/hdd"   # HDD mount point
storagePath="/storage" # Storage path
containerName=samba    # Docker container name
commandSuffix="docker exec -it $containerName" # command suffix (execute in a docker container, leave empty to execute on local machine)
confFile="/etc/samba/smb.conf"

# SAMBA functions
sambaAddOrReplaceFieldValueInSection() {
    section=$1
    field=$2
    value=$3
    file=$4

    # Uncomment section if it was commented
    $commandSuffix sed -i -e "s/^\s*#\s*\[\s*$section\s*\]\s*$/[$section]/g" $file

    # Get section start line
    startingSectionLine=$($commandSuffix grep -Ein -m 1 "^\s*\[\s*$section\s*\]\s*$" $file | cut -d: -f1)

    if [[ -z "$startingSectionLine" ]]; then # if startingSectionLine is null
        $commandSuffix sh -c "echo -e '\n[$section]\n   $field = $value' >> $file"
    else
        # Get section end line
        endingSectionLine=$($commandSuffix sed "1,${startingSectionLine}g" $file | grep -Ein -m 1 "^\s*#?\s*\[.+\]\s*$" | cut -d: -f1)

        if [[ -z "$endingSectionLine" ]]; then # if endingSectionLine is null
            endingSectionLine=$($commandSuffix grep -c "" $file)
            insertLine=$endingSectionLine
        else
            insertLine=$endingSectionLine
        fi

        # Uncomment field if it was commented
        $commandSuffix sed -i -e "$startingSectionLine,${endingSectionLine}s/^\s*#\(\s*$field\s*=.*\)$/\1/g" $file

        # Find field
        found=$($commandSuffix sed -n "$startingSectionLine,${endingSectionLine}s/^\s*$field\s*=/&/p" $file)

        if [[ -z $found ]]; then # if found is null
            $commandSuffix sed -i "${insertLine}i\   $field = $value" $file
        else
            $commandSuffix sed -i "$startingSectionLine,${endingSectionLine}s/^\s*$field\s*=.*$/   $field = $value/" $file
        fi
    fi

    echo "$file : [$section] $field = $value"
}

sambaAddOrReplaceFieldValueInSection "global" "map to guest" "bad user" "$confFile"
sambaAddOrReplaceFieldValueInSection "global" "security" "user" "$confFile"
sambaAddOrReplaceFieldValueInSection "global" "guest account" "nobody" "$confFile"
sambaAddOrReplaceFieldValueInSection "homes" "read only" "no" "$confFile"
sambaAddOrReplaceFieldValueInSection "printers" "browseable" "yes" "$confFile"
sambaAddOrReplaceFieldValueInSection "printers" "guest ok" "yes" "$confFile"

echo "========"
if [[ "$(read -p "Add HDD root as a Samba share ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    sambaAddOrReplaceFieldValueInSection "HDD" "comment" "HDD storage" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "path" "$hddMountPoint" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "browseable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "public" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "guest ok" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "guest only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "read only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "writable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "create mask" "0777" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "directory mask" "0777" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "force create mode" "0777" "$confFile"
    sambaAddOrReplaceFieldValueInSection "HDD" "force directory mode" "0777" "$confFile"
fi

echo "========"
if [[ "$(read -p "Add your 'Public', 'Shared' and 'Private' storage directories as Samba shares ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    # Public
    echo -e "\tSetup 'Public' Samba share"
    $commandSuffix mkdir -p $storagePath/Public
    $commandSuffix chown -R root:users $storagePath/Public
    $commandSuffix chmod -R 777 $storagePath/Public
    $commandSuffix find $storagePath/Public -type d -exec chmod g+s {} \;
    sambaAddOrReplaceFieldValueInSection "Public" "comment" "Public storage" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "path" "$storagePath/Public" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "browseable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "public" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "guest ok" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "guest only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "read only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "writable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "create mask" "0777" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "directory mask" "0777" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "force create mode" "0777" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Public" "force directory mode" "0777" "$confFile"

    # Shared
    echo -e "\tSetup 'Shared' Samba share"
    $commandSuffix mkdir -m 775 -p $storagePath/Shared
    $commandSuffix chown -R root:users $storagePath/Shared
    $commandSuffix chmod -R 775 $storagePath/Shared
    $commandSuffix find $storagePath/Shared -type d -exec chmod g+s {} \;
    sambaAddOrReplaceFieldValueInSection "Shared" "comment" "Shared storage" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "path" "$storagePath/Shared" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "browseable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "public" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "guest ok" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "guest only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "read only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "writable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "write list" "@users" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "create mask" "0775" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "directory mask" "0775" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "force create mode" "0775" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Shared" "force directory mode" "0775" "$confFile"

    # Private
    echo -e "\tSetup 'Private' Samba share"
    $commandSuffix mkdir -m 770 -p $storagePath/Private
    $commandSuffix chown root:users $storagePath/Private
    $commandSuffix chmod -R 770 $storagePath/Private
    $commandSuffix find $storagePath/Private -type d -exec chmod g-s {} \;
    sambaAddOrReplaceFieldValueInSection "Private" "comment" "Private storage" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "path" "$storagePath/Private" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "browseable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "public" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "guest ok" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "guest only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "read only" "no" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "writable" "yes" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "write list" "@users" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "read list" "@users" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "create mask" "0770" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "directory mask" "0770" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "force create mode" "0770" "$confFile"
    sambaAddOrReplaceFieldValueInSection "Private" "force directory mode" "0770" "$confFile"
fi

echo "========"
if [[ "$(read -p "Create a samba user named '$user' ? (y/N) : " && echo "$REPLY")" =~ ^\s*[Yy]([Ee][Ss])?\s*$ ]]; then # if user answered yes
    $commandSuffix adduser -D -H -u $uid $user $user
    $commandSuffix getent group users || $commandSuffix addgroup users
    $commandSuffix addgroup $user users
    $commandSuffix smbpasswd -a $user
fi

echo -e "\tSetup finished. Please restart the container"

echo "========"
echo "Done"
