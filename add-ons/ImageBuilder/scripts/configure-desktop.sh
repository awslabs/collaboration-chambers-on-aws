#!/bin/bash -ex

echo -e "\nInstall packages for Linux desktop"

source /etc/environment
source ${IMAGE_BUILDER_WORKDIR}/soca/source/scripts/config.cfg

cd ${IMAGE_BUILDER_WORKDIR}/scripts
cp ${IMAGE_BUILDER_WORKDIR}/soca/source/scripts/config.cfg /root
./ComputeNodeInstallDCV.sh

mkdir -p /root/sem
touch /root/sem/dcv-installed

echo -e "\nPassed"
