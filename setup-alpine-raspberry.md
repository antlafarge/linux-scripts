Setup Alpine Raspberry
======================

- Prepare SD Card
    - Wipe SD Card on Windows : `[Win]` + `[R]`, type `diskpart`
        - `list disk`
        - `select disk X`
        - `clean`
        - `exit`
    <!-- - Unplug SD Card -->
<!-- - Prepare USB Bootable stick
    - Download, install and launch PI Imager
    - Configure your Raspberry to boot from USB Sticks
    - Select and install "Other general purpose OS" > "Alpine-Linux" on the USB Stick -->
<!-- - Boot raspberry with SD Card and USB Stick plugged, it will start from USB Stick -->
    - Open Windows Disk Mmanagement tool : `[Win]` + `[R]`, type `diskmgmt.msc`
        - Create a first partition, formated in FAT32
    - Download alpine linux (file .tar.gz for raspberry pi) here : https://alpinelinux.org/downloads/
    - Extract content in SD Card root directory (boot dir must be in root dir of SD Card)
- Boot Raspberry with SD Card plugged, wait for apline boot
- Setup Alpine
    - Login with `root` (no password)
    - Prepare SD Card partitions `fdisk /dev/mmcblk0`
        - Check partions `p`
        - Note EndLBA of the partition 1
        <!-- - Create new partitions table `o` -->
        <!-- - Create new partition `n`
            - Primary `p`
            - Partition number `1`
            - Default (press enter)
            - Set 1 GB `+1G` -->
        - Create new partition `n`
            - Primary `p`
            - Partition number `2`
            - Must be (EndLBA + 1) of partition 1 noted before
            - Default all remaining size (press enter)
        <!-- - Partition type `t`
            - Partition number `1`
            - Partition type Linux `83` -->
        - Partition type `t`
            - Partition number `2`
            - Partition type Linux `83`
        - w
        - Check with `fdisk -l /dev/mmcblk0`
    - `setup-alpine`
        - Follow instructions
            - fr
            - fr
            - pi4
            - eth0
            - dhcp
            - done (instead of wlan0)
            - n
            - Type new root password
            - Europe/Paris
            - none
            - chrony
            - c (enable community repos)
            - 86 (ovh) or 1
            - Type username
            - Type real name
            - Type user password
            - none
            - openssh
        - When it asks for **Disk & Install** : Which disk do you want to use ?
        OR No disks available...
            - Don't answer now, switch to tty2 (`[CTRL]` + `[ALT]` + `[2]`)
            - Login as `root` with your new password
            - `apk update`
            - `apk add nano e2fsprogs`
            <!-- - Format part 1 with ext4 `mkfs.ext4 /dev/mmcblk0p1` -->
            - Format part 2 with ext4 `mkfs.ext4 /dev/mmcblk0p2`
            - mkdir -p /media/mmcblk0p2
            - nano /etc/fstab
                - `/dev/mmcblk0p2 /media/mmcblk0p2 ext4 defaults 0 0`
            - mount -a
            - Exit tty2 : exit
            - Switch back to tty1 (`[CTRL]` + `[ALT]` + `[1]`)
        - Disk & install
            - Which disk(s) would you like to use ? Diskless `none`
            - Enter where to store configs ? Part 2 `mmcblk0p2`
            - Apk cache directory ? In partition 2 `/media/mmcblk0p2/cache`
        <!-- - Install alpine on mmcblk0p1 :
            - mount /dev/mmcblk0p1 /mnt
            - sys-install /mnt
            - chroot /mnt
            - apk add syslinux
            - syslinux --install /dev/mmcblk0p1
            - nano /etc/fstab
                - Add `/dev/mmcblk0p1 / ext4 defaults 0 1`
            - exit
            - reboot -->
        - Delete and reinstall packages to `/media/mmcblk0p2/cache`
            - apk del nano e2fsprogs
            - apk update
            - apk upgrade
            - apk add nano e2fsprogs bash util-linux
    - Save RAM changes to SD Card `lbu commit -d`
