## Setup Debian

## Enable sudo

```bash
su -
apt update
apt install sudo
sudo usermod -a -G sudo [username]
exit
su [username]
```
