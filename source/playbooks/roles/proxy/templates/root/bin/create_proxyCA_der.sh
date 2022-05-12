#!/bin/bash -xe

cd /etc/squid/ssl_cert
openssl x509 -in proxyCA.pem -outform DER -out proxyCA.der
