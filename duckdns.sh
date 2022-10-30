#!/bin/bash

# Usage : ./duckdns.sh "myDomain" "myToken"

domain="$1"

token="$2"

regexPattern="\{\"ip\":\"(.+)\"\}"

ipV4=$(curl -s "https://api.ipify.org/?format=json" | sed -r "s/${regexPattern}/\1/")

ipV6=$(curl -s "https://api64.ipify.org/?format=json" | sed -r "s/${regexPattern}/\1/")

duckDnsUrl="https://www.duckdns.org/update?domains=${domain}&token=${token}&verbose=true"

if [ -n "${ipV4}" ]
then
    duckDnsUrl="${duckDnsUrl}&ip=${ipV4}"
fi

if [ -n "${ipV6}" ]
then
    duckDnsUrl="${duckDnsUrl}&ipv6=${ipV6}"
fi

res=$(curl -s "${duckDnsUrl}")

if [ "$?" -ne 0 ]
then
    echo "Update duckdns.org failed"
    echo "duckDnsUrl=${duckDnsUrl}"
fi
