#!/bin/bash

if grep -q 'Amazon Linux release 2' /etc/system-release; then
    BASE_OS=amazonlinux2
elif grep -q 'CentOS Linux release 7' /etc/system-release; then
    BASE_OS=centos7
else
    BASE_OS=rhel7
fi
echo $BASE_OS
