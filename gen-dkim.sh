#!/bin/bash

openssl genrsa -out dkim-private.key 2048
openssl rsa -in dkim-private.key -pubout -out dkim-public.key
cp dkim-public.key dkim-dns.txt
res=$(tr -d '\n' < dkim-dns.txt)
echo $res > dkim-dns.txt
sed -i -r "s|^-+?[^-]+?-+?([^-?]+?)-+?[^-]+?-+?$|<selector>._domainkey IN TXT v=DKIM1; k=rsa; p=\1|" dkim-dns.txt
echo "keys generated"
cat dkim-dns.txt
