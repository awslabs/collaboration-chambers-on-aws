#!/bin/bash -ex

scriptdir=$(dirname $(readlink -f $0))
scriptsdir=$(readlink -f $scriptdir/..)
socadir=$(readlink -f $scriptdir/../..)

install_packages=${scriptdir}/install_packages.sh

source /etc/environment
source ${IMAGE_BUILDER_WORKDIR}/soca/source/scripts/config.cfg

function info {
    echo "$(date):INFO: $1"
}

function error {
    echo "$(date):ERROR: $1"
}

if grep -q 'Amazon Linux release 2' /etc/system-release; then
    BASE_OS=amazonlinux2
elif grep -q 'CentOS Linux release 7' /etc/system-release; then
    BASE_OS=centos7
else
    BASE_OS=rhel7
fi
export BaseOS=$BASE_OS
info "BaseOS=$BaseOS"

# Install epel
info "Installing epel"
if [ $BaseOS == "amazonlinux2" ]; then
    # The amazon-linux-extras version is missing figlet
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
elif [ $BaseOS == "centos7" ]; then
    yum -y install epel-release
elif [ $BaseOS == "rhel7" ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi

# Install ansible
info "Installing ansible"
if [ $BaseOS == "amazonlinux2" ]; then
    amazon-linux-extras enable ansible2
fi
yum -y install ansible

# Install pip
if which pip2.7; then
    echo "pip2.7 already installed"
else
    echo "Installing pip2.7"
fi
if [ "$BaseOS" == "centos7" ] || [ "$BaseOS" == "rhel7" ]; then
    if ! yum list installed python2-pip &> /dev/null; then
        echo "Installing python2-pip"
        # easy_install-2.7 installs a new version of pip that fails on python2.7
        yum -y install python2-pip
    fi
fi
PIP=$(which pip2.7)
# Make sure pip works
$PIP --version

# awscli is installed by the aws-cli-version-2-linux component
AWS=$(which aws)

# Download Ansible Playbooks
info "Downloading ansible playbooks"
rm -rf /root/playbooks
aws s3 cp --recursive s3://${SOCA_INSTALL_BUCKET}/${SOCA_INSTALL_BUCKET_FOLDER}/playbooks/ /root/playbooks/
cd /root/playbooks

# Install Lustre client
if [ "$BaseOS" == "amazonlinux2" ]; then
    sudo amazon-linux-extras install -y lustre2.10
elif [ "$BaseOS" == "centos7" ] || [ "$BaseOS" == "rhel7" ]; then
    curl https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-rpm-public-key.asc -o /tmp/fsx-rpm-public-key.asc
    rpm --import /tmp/fsx-rpm-public-key.asc
    curl https://fsx-lustre-client-repo.s3.amazonaws.com/el/7/fsx-lustre-client.repo -o /etc/yum.repos.d/aws-fsx.repo
    yum install -y kmod-lustre-client lustre-client
fi

# Don't configure file system mounts so that image can be used by different VPCs
# Can't mount them in the public subnet
#echo -e "\nConfiguring mount of $EFS_DATA at /data"
#mkdir -p /data
#echo "$EFS_DATA:/ /data nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab
#echo -e "\nConfiguring mount of $EFS_APPS at /apps"
#mkdir -p /apps
#echo "$EFS_APPS:/ /apps nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0" >> /etc/fstab

if [ "$BaseOS" == "rhel7" ]; then
    yum-config-manager --enable rhui-REGION-rhel-server-optional
    yum-config-manager --enable rhel-7-server-rhui-optional-rpms
    yum-config-manager --enable rhel-7-server-rhui-rpms
fi

mkdir -p /root/logs

rc=0

info "Installing SYSTEM_PKGS"
if ! $install_packages "yum list installed" "yum install -y" ${SYSTEM_PKGS[*]} &> /root/logs/system_pkgs.log; then
    cat /root/logs/system_pkgs.log
    rc=1
fi

info "Installing SCHEDULER_PKGS"
if ! $install_packages "yum list installed" "yum install -y" ${SCHEDULER_PKGS[*]} &> /root/logs/scheduler_pkgs.log; then
    cat /root/logs/scheduler_pkgs.log
    rc=1
fi

info "Installing OPENLDAP_SERVER_PKGS"
if ! $install_packages "yum list installed" "yum install -y" ${OPENLDAP_SERVER_PKGS[*]} &> /root/logs/openldap_server_pkgs.log; then
    cat /root/logs/openldap_server_pkgs.log
    rc=1
fi

info "Installing SSSD_PKGS"
if ! $install_packages "yum list installed" "yum install -y" ${SSSD_PKGS[*]} &> /root/logs/sssd_pkgs.log; then
    cat /root/logs/sssd_pkgs.log
    rc=1
fi
if [ $rc != "0" ]; then
    echo "error: Failed"
    exit $rc
fi
mkdir -p /root/sem
touch /root/sem/soca-packages-installed

# Install PBS Pro
cd /root
wget $OPENPBS_URL
tar zxvf $OPENPBS_TGZ
cd openpbs-$OPENPBS_VERSION
./autogen.sh
./configure --prefix=/opt/pbs
if ! make -j6 &> openpbs_build.log; then
    cat openpbs_build.log
    exit 1
fi
if ! make install -j6 &> openpbs_install.log; then
    cat openpbs_install.log
    exit 1
fi
/opt/pbs/libexec/pbs_postinstall
chmod 4755 /opt/pbs/sbin/pbs_iff /opt/pbs/sbin/pbs_rcp
systemctl disable pbs
touch /root/sem/pbs-installed

systemctl disable libvirtd.service || true
if ifconfig virbr0; then
    ip link set virbr0 down
    brctl delbr virbr0
fi
systemctl disable firewalld || true
systemctl stop firewalld || true
