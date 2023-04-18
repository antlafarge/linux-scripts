#!/bin/bash

# Usage : sudo ./build-openvpn-docker.sh

# https://www.grottedubarbu.fr/serveur-openvpn-5-minutes-docker

container=$(docker ps -a | grep "openvpn")

baseDir="$PWD"
openVpnDir="$baseDir/openvpn"

if [ -z "$container" ]
then
    echo "======== INSTALL GIT ========"

    sudo apt-get install git

    echo "======== GET SOURCES ========"

    mkdir -p "$openVpnDir/"
    cd "$openVpnDir/"

    if [ -d "$openVpnDir/docker-openvpn/" ]
    then
        git pull https://github.com/kylemanna/docker-openvpn.git
    else
        git clone https://github.com/kylemanna/docker-openvpn.git
    fi

    cd "$baseDir/"

    echo "======== BUILD OPENVPN IMAGE ========"

    docker rmi openvpn
    docker build -t openvpn -f "$openVpnDir/docker-openvpn/Dockerfile" "$openVpnDir/docker-openvpn/"

    echo "======== OPENVPN GEN CONFIG ========"

    printf "Type the URL you will use to access the VPN (Example 'udp://myUser.duckdns.org:1194') : "
    read url

    if [ -z "$url" ]
    then
        echo "Bad url"
        exit 1
    fi

    docker run -v "$openVpnDir/etc/:/etc/openvpn/" --rm openvpn ovpn_genconfig -u "$url"

    echo "======== OPENVPN INIT CERT ========"
    echo "This is the configuration for the openvpn CA. User accounts will be created after."

    docker run -v "$openVpnDir/etc/:/etc/openvpn/" --rm -it openvpn ovpn_initpki

    echo "======== DOCKER RUN OPENVPN ========"
    docker run -d --name openvpn --restart on-failure:10 -v "$openVpnDir/etc/:/etc/openvpn/" -p "1194:1194/udp" --cap-add NET_ADMIN openvpn
else
    docker start openvpn
fi

printf "Username : "
read -r username
usernamePath="$openVpnDir/$username.ovpn"

if [ ! -f "$openVpnDir/$username.ovpn" ]
then
    echo "======== OPENVPN CLIENT CONFIG CREATE ========"
    echo "This is the configuration for one user."

    docker run -v "$openVpnDir/etc/:/etc/openvpn/" --rm -it openvpn easyrsa build-client-full "$username"

    echo "======== OPENVPN CLIENT CONFIG EXTRACT ========"

    docker run -v "$openVpnDir/etc/:/etc/openvpn/" --rm openvpn ovpn_getclient "$username" > "$usernamePath"

    echo "Client config extracted ($usernamePath)."
    echo "Get this config to connect to the VPN."
fi

echo "======== Finished ========"
