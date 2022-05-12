#!/bin/bash -xe

function on_exit {
    rc=$?
    info "Exiting with rc=$rc"
    exit $rc
}
trap on_exit EXIT

function info {
    echo "$(date):INFO: $1"
}

function error {
    echo "$(date):ERROR: $1"
}

info "Starting $0"

source /etc/environment
source /root/config.cfg
if [ -e /etc/profile.d/proxy.sh ]; then
    source /etc/profile.d/proxy.sh
fi

INSTANCE_FAMILY=`curl --silent  http://169.254.169.254/latest/meta-data/instance-type | cut -d. -f1`
echo "detected Instance family $INSTANCE_FAMILY"
GPU_INSTANCE_FAMILY=(g3 g4 g4dn)

# Enable GPU support
if [[ "${GPU_INSTANCE_FAMILY[@]}" =~ "${INSTANCE_FAMILY}" ]];
then
    echo "Detected GPU instance, adding support for nice-dcv-gl"
    if ! rpm -ivh nice-dcv-gl*.rpm --nodeps &> dcv-install.log; then
        cat dcv-install.log
        if grep -q 'already installed' dcv-install.log; then
            echo -e "\nDCV packages already installed"
        else
            echo -e "\nerror: DCV package install failed"
        fi
    else
        cat dcv-install.log
        echo -e "\nInstalled DCV packages"
    fi
    #DCVGLADMIN=$(which dcvgladmin)
    #$DCVGLADMIN enable
fi

# Automatic start Gnome upon reboot
systemctl set-default graphical.target

DCVGLADMIN=$(which dcvgladmin)
$DCVGLADMIN disable

# Configure DCV
mv /etc/dcv/dcv.conf /etc/dcv/dcv.conf.orig
IDLE_TIMEOUT=1440 # in minutes. Disconnect DCV (but not terminate the session) after 1 day if not active
USER_HOME=$(eval echo ~$SOCA_DCV_OWNER)
DCV_STORAGE_ROOT="$USER_HOME/storage-root" # Create the storage root location if needed
mkdir -p $DCV_STORAGE_ROOT
chown -R $SOCA_DCV_OWNER:$SOCA_DCV_OWNER $USER_HOME
chown $SOCA_DCV_OWNER:$SOCA_DCV_OWNER $DCV_STORAGE_ROOT

DCV_HOST_ALTNAME=$(hostname | cut -d. -f1)

echo -e """
[license]
[log]
[session-management]
virtual-session-xdcv-args=\"-listen tcp\"
[session-management/defaults]
[session-management/automatic-console-session]
storage-root=\"$DCV_STORAGE_ROOT\"
[display]
# add more if using an instance with more GPU
cuda-devices=[\"0\"]
[display/linux]
gl-displays = [\":1.0\"]
[display/linux]
use-glx-fallback-provider=false
[connectivity]
web-url-path=\"/$DCV_HOST_ALTNAME\"
idle-timeout=$IDLE_TIMEOUT
[security]
auth-token-verifier=\"$SOCA_DCV_AUTHENTICATOR\"
no-tls-strict=true
os-auto-lock=false
""" > /etc/dcv/dcv.conf

# Start DCV server
sudo systemctl enable dcvserver
sudo systemctl stop dcvserver
sleep 5
sudo systemctl start dcvserver

systemctl stop firewalld || true
systemctl disable firewalld || true

# Start X
systemctl isolate graphical.target

# Start Session
echo "Launching session ... : dcv create-session --user $SOCA_DCV_OWNER --owner $SOCA_DCV_OWNER --type virtual --storage-root $DCV_STORAGE_ROOT $SOCA_DCV_SESSION_ID"
dcv create-session --user $SOCA_DCV_OWNER --owner $SOCA_DCV_OWNER --type virtual --storage-root "$DCV_STORAGE_ROOT" $SOCA_DCV_SESSION_ID
echo $?
echo "Session created"
sleep 5

# Final reboot is needed to update GPU drivers if running GPU instance. Reboot will be triggered by ComputeNodePostReboot.sh
if [[ "${GPU_INSTANCE_FAMILY[@]}" =~ "${INSTANCE_FAMILY}" ]];
then
  echo "@reboot dcv create-session --owner $SOCA_DCV_OWNER --storage-root \"$DCV_STORAGE_ROOT\" $SOCA_DCV_SESSION_ID # Do Not Delete"| crontab - -u $SOCA_DCV_OWNER
  exit 3 # notify ComputeNodePostReboot.sh to force reboot
else
  echo "@reboot dcv create-session --owner $SOCA_DCV_OWNER --storage-root \"$DCV_STORAGE_ROOT\" $SOCA_DCV_SESSION_ID # Do Not Delete"| crontab - -u $SOCA_DCV_OWNER
  exit 0
fi
