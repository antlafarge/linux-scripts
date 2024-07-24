#!/bin/bash

# Usage :
#     ./duckdns.sh "myDomain" "myToken"
# Example for "example.duckdns.org" :
#     ./duckdns.sh "example" "12345678-1234-1234-1234-123456789ABC"
# crontab :
#     crontab -e
# Add this line to execute the script (every day) :
#     0 0,12 * * * /home/[MyUser]/duckdns.sh "myDomain" "myToken"
#     This command will execute the duckdns script at minute 0 past hour 0 and 12 every day

domain="$1"

token="$2"

regexPattern="\{\"ip\":\"(.+)\"\}"

ipV4=$(curl -s "https://api.ipify.org/?format=json" | sed -r "s/${regexPattern}/\1/")

ipV6=$(curl -s "https://api64.ipify.org/?format=json" | sed -r "s/${regexPattern}/\1/")

duckDnsUrl="https://www.duckdns.org/update?domains=${domain}&token=${token}&verbose=true"

if [ -n "${ipV4}" ]; then
    duckDnsUrl="${duckDnsUrl}&ip=${ipV4}"
fi

if [ -n "${ipV6}" ] && [ "${ipV4}" != "${ipV6}" ]; then
    duckDnsUrl="${duckDnsUrl}&ipv6=${ipV6}"
fi

res=$(curl -s "${duckDnsUrl}")

if [ "$res" = "KO" ]; then
    echo "Update duckdns.org failed"
    echo "duckDnsUrl=${duckDnsUrl}"
    echo "result=${res}"
fi
