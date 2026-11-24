#!/bin/bash

dir="dkim-$(date +%Y-%m-%dT%H:%M:%S)"
mkdir $dir
cd $dir

openssl genrsa -out dkim-private.key 2048
openssl rsa -in dkim-private.key -pubout -out dkim-public.key

publicKey=$(sed '/^-.*-$/d' dkim-public.key | tr -d '\n')

printf "<selector>._domainkey IN TXT v=DKIM1; k=rsa; p=$publicKey" > dns-record.txt

cd ..

echo "keys generated in dir : \"$dir\""
