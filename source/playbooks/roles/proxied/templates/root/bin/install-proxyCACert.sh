#!/bin/bash -ex

target=/etc/pki/ca-trust/source/anchors/proxyCA.pem
function on_exit {
    rc=$?
    if [ $rc -ne 0 ]; then
        rm $target
        exit $rc
    fi
}
trap on_exit EXIT

parameter_name="{{ProxyCACertParameterName}}"
aws --region {{Region}} ssm get-parameter --name $parameter_name --query 'Parameter.Value' --output text > $target
update-ca-trust
