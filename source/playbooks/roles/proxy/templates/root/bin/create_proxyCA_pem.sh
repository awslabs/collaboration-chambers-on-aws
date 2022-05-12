#!/bin/bash -ex

function on_exit {
    rc=$?
    if [ $rc -ne 0 ]; then
        rm /etc/squid/ssl_cert/proxyCA.pem
        exit $rc
    fi
}
trap on_exit EXIT

if [ ! -d /etc/squid/ssl_cert ]; then
    mkdir /etc/squid/ssl_cert
    chmod 0600 /etc/squid/ssl_cert
    chown squid:squid /etc/squid/ssl_cert
fi
cd /etc/squid/ssl_cert
parameter_name="{{ProxyCACertParameterName}}"
if [ ! -e proxyCA.pem ]; then
    # Check to see if it has already been created, possibly by an older instance of the proxy
    proxyCACert=$(aws --region {{Region}} ssm get-parameter --name $parameter_name --query 'Parameter.Value' --output text || echo UNDEFINED)
    if [ "$proxyCACert" != "UNDEFINED" ]; then
        aws --region {{Region}} ssm get-parameter --name $parameter_name --query 'Parameter.Value' --output text >  proxyCA.pem
    else
        openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -subj "/O=SOCAProxy/CN={{Domain}}" -extensions v3_ca -keyout proxyCA.pem -out proxyCA.pem
        proxyCACert=$(cat /etc/squid/ssl_cert/proxyCA.pem)
        aws --region {{Region}} ssm put-parameter --type String --overwrite --name $parameter_name --value "$proxyCACert"
    fi
    rm -f /etc/pki/ca-trust/source/anchors/proxyCA.pem
    ln -s /etc/squid/ssl_cert/proxyCA.pem /etc/pki/ca-trust/source/anchors
    update-ca-trust
fi
