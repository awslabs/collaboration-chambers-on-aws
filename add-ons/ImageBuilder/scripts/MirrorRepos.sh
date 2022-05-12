#!/bin/bash -ex

function sync_to_s3 {
    # Intermediate sync
    aws s3 sync ${repo_dir} ${s3_repo_url}
}

function on_exit {
    rc=$?
    set +e
    if [[ $rc -ne 0 ]]; then
        echo Failed
        echo "Failed" > $repo_dir/failed.txt
        echo "Saving intermediate results"
        sync_to_s3
    else
        echo "Passed" > $repo_dir/passed.txt
        sync_to_s3
    fi
}
trap on_exit EXIT

echo -e "\nMirror repos and source code for SOCA"

scriptdir=$(dirname $(readlink -f $0))

install_packages=${scriptdir}/install_packages.sh

function info {
    echo "$(date):INFO: $1"
}

function error {
    echo "$(date):ERROR: $1"
}

# For some reason whoami says root but USER and USERNAME aren't set.
export LOGNAME=$(whoami)
export HOME=/$(whoami)
export USER=$(whoami)
export USERNAME=$(whoami)

source /etc/environment
source ${IMAGE_BUILDER_WORKDIR}/soca/source/scripts/config.cfg

if grep -q 'Amazon Linux release 2' /etc/system-release; then
    BASE_OS=amazonlinux2
elif grep -q 'CentOS Linux release 7' /etc/system-release; then
    BASE_OS=centos7
else
    BASE_OS=rhel7
fi
info $BASE_OS
export BaseOS="$BASE_OS"
info "BaseOS=${BaseOS}"

# Mount EBS volume for repo
if ! mountpoint -q /repo; then
    lsblk
    mkfs.ext4 /dev/nvme1n1
    mkdir -p /repo
    mount /dev/nvme1n1 /repo
    rm -rf /repo/lost+found
    df -h /repo
fi

export build_dir="/tmp/MirrorRepos"
export repo_dir="/repo"
export os_repo_dir="$repo_dir/yum/$BASE_OS"

export timestamp="$(date +%Y-%m-%d-%H-%M-%S)"

rm -rf $build_dir
mkdir -p $build_dir
mkdir -p $repo_dir
mkdir -p $repo_dir/source
mkdir -p $os_repo_dir

export s3_repo_url="s3://${SOCA_REPOSITORY_BUCKET}/${SOCA_REPOSITORY_FOLDER}/${BASE_OS}/${timestamp}"
export s3_os_repo_url="$s3_repo_url/yum/$BASE_OS"

cd $build_dir

if ! yum list installed epel-release &> /dev/null; then
    if [ $BASE_OS == "centos7" ]; then
        yum install -y epel-release
    else
        yum install -y  https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    fi
fi

$install_packages "yum list installed" "yum install -y" createrepo make rpm-build wget which yum-utils python2-pip

if [ $BASE_OS == "centos7" ]; then
    $install_packages "yum list installed" "yum install -y" groff
else
    $install_packages "yum list installed" "yum install -y" groff-base
fi

which pip

pip install mock

# awscli is installed by previous component

# Save awscli rpm so can be installed from private VPC
wget https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
mkdir -p ${repo_dir}/source
cp awscli-exe-linux-x86_64.zip ${repo_dir}/source/awscli-exe-linux-x86_64.zip

# Intermediate sync
sync_to_s3

ls /etc/pki/rpm-gpg
#rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
#rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

mkdir -p ${repo_dir}
cp -r /etc/pki/rpm-gpg ${repo_dir}

# Intermediate sync
sync_to_s3

# Install fsx lustre client
curl https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-rpm-public-key.asc -o /tmp/fsx-rpm-public-key.asc
cp /tmp/fsx-rpm-public-key.asc ${repo_dir}/fsx-rpm-public-key.asc
rpm --import /tmp/fsx-rpm-public-key.asc
curl https://fsx-lustre-client-repo.s3.amazonaws.com/el/7/fsx-lustre-client.repo -o /etc/yum.repos.d/aws-fsx.repo
yum --disablerepo="*" --enablerepo="aws-fsx" list available
yum --disablerepo="*" --enablerepo="aws-fsx-src" list available

echo $BASE_OS

if [ "$BASE_OS" == "rhel7" ]; then
    yum-config-manager --enable rhui-REGION-rhel-server-optional
    yum-config-manager --enable rhel-7-server-rhui-optional-rpms
    yum-config-manager --enable rhel-7-server-rhui-rpms
fi

$install_packages "yum list installed" "yum install -y" ${SYSTEM_PKGS[@]}
$install_packages "yum list installed" "yum install -y" ${SCHEDULER_PKGS[@]}
$install_packages "yum list installed" "yum install -y" ${OPENLDAP_SERVER_PKGS[*]}
$install_packages "yum list installed" "yum install -y" ${SSSD_PKGS[*]}

# Copy PBSPRO tarball
wget -q $OPENPBS_URL
mkdir -p ${repo_dir}/source/openpbs/
cp $OPENPBS_TGZ ${repo_dir}/source/openpbs/$OPENPBS_TGZ

# Intermediate sync
sync_to_s3

# Copy Python tarball
wget -q $PYTHON_URL
if [[ $(md5sum $PYTHON_TGZ | awk '{print $1}') != $PYTHON_HASH ]];  then
    echo -e "FATAL ERROR: Checksum for Python failed. File may be compromised." > /etc/motd
    exit 1
fi
mkdir -p ${repo_dir}/source/python
cp $PYTHON_TGZ ${repo_dir}/source/python/$PYTHON_TGZ

# Intermediate sync
sync_to_s3

# Copy OpenMPI tarball
wget -q $OPENMPI_URL
mkdir -p ${repo_dir}/source/openmpi
cp $OPENMPI_TGZ ${repo_dir}/source/openmpi/$OPENMPI_TGZ

# Intermediate sync
sync_to_s3

# Copy Metric Beat tarball
wget -q $METRICBEAT_URL
mkdir -p ${repo_dir}/source/metricbeat
cp $METRICBEAST_RPM ${repo_dir}/source/metricbeat/$METRICBEAST_RPM

# Intermediate sync
sync_to_s3

# Copy DCV package
mkdir -p $repo_dir/source/dcv
cd $repo_dir/source/dcv
wget $DCV_X86_64_URL
wget $DCV_AARCH64_URL

# Intermediate sync
sync_to_s3

# Copy DCV viewer package
# Get latest download URL from Nice DCV
cd $build_dir
mkdir -p dcvviewer
cd dcvviewer
machine=$(uname -m)
fields=( $(curl https://download.nice-dcv.com | grep -E "\"https://.+/nice-dcv-viewer-.+\.el7\.$machine\.rpm\"" | tr '"' '\n') )
url=${fields[1]}
wget $url
mkdir -p ${repo_dir}/source/dcvviewer/
cp *.rpm ${repo_dir}/source/dcvviewer/

# Intermediate sync
sync_to_s3

cd $build_dir
aws s3 sync s3://${SOCA_INSTALL_BUCKET}/${SOCA_INSTALL_BUCKET_FOLDER}/source/yum-s3-iam ${s3_repo_url}/source/yum-s3-iam
aws s3 sync s3://${SOCA_INSTALL_BUCKET}/${SOCA_INSTALL_BUCKET_FOLDER}/source/yum-s3-iam yum-s3-iam
cd yum-s3-iam
make rpm
cp /root/rpmbuild/RPMS/noarch/yum-plugin-s3-iam-1.2.2-1.noarch.rpm $repo_dir/yum/

# Intermediate sync
sync_to_s3

# For some reason whoami says root but USER and USERNAME are not set.
export LOGNAME=$(whoami)
export HOME=/$(whoami)
export USER=$(whoami)
export USERNAME=$(whoami)

env | sort > /root/env.txt
rpm --eval '%{_topdir}'

cd $build_dir
    
echo "List of yum repos:"
yum repolist

# Build Python and install required packages
# This is so that a PyPi mirror isn't required.
mkdir -p /apps/soca/$SOCA_CONFIGURATION/python/installer
cd /apps/soca/$SOCA_CONFIGURATION/python/installer
tar xzf $build_dir/$PYTHON_TGZ
cd Python-$PYTHON_VERSION
logfile=/var/log/Python-build.log
echo "Configuring python build"
if ! ./configure LDFLAGS="-L/usr/lib64/openssl" CPPFLAGS="-I/usr/include/openssl" -enable-loadable-sqlite-extensions --prefix=/apps/soca/$SOCA_CONFIGURATION/python/$PYTHON_VERSION >> $logfile 2>1; then
    cat $logfile
    echo "Python configure failed"
    exit 1
fi
echo "Building Python"
if ! make >> $logfile 2>1; then
    cat $logfile
    echo "Python build failed"
    exit 1
fi
echo "Installing Python"
if ! make install >> $logfile 2>1; then
    cat $logfile
    echo "Python install failed"
    exit 1
fi
cd /apps/soca/$SOCA_CONFIGURATION/python
compiled_python_tgz=Python-$PYTHON_VERSION-compiled.tgz

echo "Install Python required libraries"
aws s3 cp --quiet s3://${SOCA_INSTALL_BUCKET}/${SOCA_INSTALL_BUCKET_FOLDER}/soca/source/scripts/requirements.txt /root/
if ! /apps/soca/$SOCA_CONFIGURATION/python/$PYTHON_VERSION/bin/pip3 install -r /root/requirements.txt >> $logfile 2>1; then
    cat $logfile
    echo "Python requirements install failed"
    exit 1
fi

compiled_python_tgz=Python-${PYTHON_VERSION}-compiled.tgz
tar -czf $compiled_python_tgz $PYTHON_VERSION
mkdir -p ${repo_dir}/source/python
cp $compiled_python_tgz ${repo_dir}/source/python/$compiled_python_tgz

# Intermediate sync
sync_to_s3

cd $build_dir

if [ "$BASE_OS" == "centos7" ]; then
    export required_repos=( \
        base updates extras centosplus \
        epel epel-debuginfo epel-source \
        aws-fsx \
        aws-fsx-src \
    )
    export optional_repos=( \
        base-debuginfo \
        cr \
        fasttrack \
        base-source updates-source extras-source centosplus-source \
        centos-kernel centos-kernel-experimental \
        epel-testing epel-testing-debuginfo epel-testing-source \
    )
elif [ "$BASE_OS" == "rhel7" ]; then
    export required_repos=( \
        rhel-7-server-rhui-optional-rpms \
        rhel-7-server-rhui-rh-common-rpms \
        rhel-7-server-rhui-rpms \
        rhui-client-config-server-7 \
        epel \
        aws-fsx \
        aws-fsx-src \
    )
    export optional_repos=( \
    )
fi
echo ${required_repos[@]}

echo ${optional_repos[@]}

export repos=( \
    ${required_repos[@]} \
    #${optional_repos[@]} \
)
echo ${repos[@]}

# Save successes so can rerun after fails without redoing work
sem_dir=$build_dir/sems
mkdir -p $sem_dir
for repo in ${repos[@]}; do
    reposync_sem=$sem_dir/${repo}.reposync_done.txt
    createrepo_sem=$sem_dir/${repo}.createrepo_done.txt
    if [ -e $reposync_sem ]; then
        echo "reposync already passed for $repo"
    else
        info "Syncing $repo"
        rm -f $createrepo_sem
        echo -e "\nreposync --quiet -g -l -p $os_repo_dir --source --downloadcomps --download-metadata -r $repo"
        if ! reposync --quiet -g -l -p $os_repo_dir --source --downloadcomps --download-metadata -r $repo; then
            rc=$?
            echo -e "warning: reposync failed with rc=$rc but trying to continue. GPC may have failed on a package."''
        fi
        echo "df -h ."; df -h .
        touch $reposync_sem

        # Intermediate sync
        sync_to_s3
    fi


    if [ -e $createrepo_sem ]; then
        echo "createrepo already passed for $repo"
    else
        if [ -e $os_repo_dir/$repo/comps.xml ]; then
            groups_arg="-g comps.xml"
        else
            groups_arg=""
        fi

        echo -e "\ncreaterepo $os_repo_dir/$repo $groups_arg"
        createrepo $os_repo_dir/$repo $groups_arg
        date; echo "df -h ."; df -h .
        touch $createrepo_sem

        # Intermediate sync
        sync_to_s3
    fi
done

# Save the S3 repository in an SSM parameter
aws ssm put-parameter --name "/${SOCA_CLOUDFORMATION_STACK}/repositories/${SOCA_BASE_OS}/${timestamp}/RepositoryBucket" --type String --value "${SOCA_REPOSITORY_BUCKET}" --overwrite
aws ssm put-parameter --name "/${SOCA_CLOUDFORMATION_STACK}/repositories/${SOCA_BASE_OS}/${timestamp}/RepositoryFolder" --type String --value "${SOCA_REPOSITORY_FOLDER}/${BASE_OS}/${timestamp}" --overwrite
aws ssm put-parameter --name "/${SOCA_CLOUDFORMATION_STACK}/repositories/${SOCA_BASE_OS}/latest/RepositoryBucket" --type String --value "${SOCA_REPOSITORY_BUCKET}" --overwrite
aws ssm put-parameter --name "/${SOCA_CLOUDFORMATION_STACK}/repositories/${SOCA_BASE_OS}/latest/RepositoryFolder" --type String --value "${SOCA_REPOSITORY_FOLDER}/${BASE_OS}/${timestamp}" --overwrite

export s3_repo_url="s3://${SOCA_REPOSITORY_BUCKET}/${SOCA_REPOSITORY_FOLDER}/${BASE_OS}/${timestamp}"

# Create an EBS snapshot of the repo volume
umount /repo
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
volume_id=$(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$instance_id Name=attachment.device,Values=/dev/sdf --query 'Volumes[0].Attachments[0].VolumeId' --output text)
snapshot_id=$(aws ec2 create-snapshot --volume-id $volume_id --query SnapshotId --output text)
parameter_name_tagged="/${SOCA_CLOUDFORMATION_STACK}/repositories/${SOCA_BASE_OS}/${timestamp}/SnapshotId"
parameter_name_latest="/${SOCA_CLOUDFORMATION_STACK}/repositories/${SOCA_BASE_OS}/latest/SnapshotId"
aws ssm put-parameter --name $parameter_name_tagged --type String --value $snapshot_id --overwrite
aws ssm put-parameter --name $parameter_name_latest --type String --value $snapshot_id --overwrite

# Final sync
sync_to_s3

echo repo_dir=${repo_dir}

echo "Yum repo: ${s3_repo_url}"

echo -e "\nPassed"
