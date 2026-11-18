## Setup Debian

## Enable sudo

```bash
su -
apt update
apt install sudo
sudo usermod -a -G sudo [username]
exit
su [username]
groups
```

## Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker [username]
su [username]
groups
```
