#!/bin/bash -ex

scriptdir=$(dirname $(readlink -f $0))

install_packages=${scriptdir}/install_packages.sh

function info {
    echo "$(date):INFO: $1"
}

function error {
    echo "$(date):ERROR: $1"
}

yum install -y epel-release

eda_yum_packages=(
    apr-util
    bc
    bzip2-devel
    cmake
    cmake3
    collectd
    compat-db47
    compat-libstdc++-33.x86_64
    compat-libstdc++-33.i686
    compat-libtiff3
    csh
    ctags
    dos2unix
    elfutils-libelf.x86_64
    elfutils-libelf.i686
    emacs
    environment-modules
    fuse
    fuse-libs
    gcc
    gcc-c++
    gd
    gdb
    glibc
    glibc.i686
    gpaste
    gpaste-ui
    git
    git-lfs
    gnuplot
    gperf
    gstreamer
    indent
    jq
    js
    krb5-workstation
    ksh
    libaio
    libffi-devel
    libICE.x86_64
    libICE.i686
    libmng
    libpng12
    libSM.x86_64
    libSM.i686
    libstdc++.x86_64
    libstdc++.i686
    libstdc++-docs
    libX11-devel
    libXcursor.x86_64
    libXcursor.i686
    libXdmcp
    libXext.x86_64
    libXext.i686
    libXmu
    libXp
    libXrandr.x86_64
    libXrandr.i686
    libXScrnSaver
    lsof
    lzma-sdk-devel
    make
    man-pages
    meld
    mesa-libGLU
    ncurses-devel
    ncurses-libs.x86_64
    ncurses-libs.i686
    nedit
    net-tools
    nfs-utils
    nodejs
    npm
    openldap-clients
    openssh-clients
    openssl-devel
    pandoc # For generating html from markdown
    parallel
    perf
    perl-XML-Parser
    pulseaudio-libs
    python2-pip
    python3
    python3-pip
    qt
    qt3
    readline-devel
    redhat-lsb
    screen
    socat
    sqlite-devel
    strace
    stress
    tcl
    tcl-devel
    tcpdump
    tcsh
    tigervnc
    time
    tk
    tk-devel
    tkcvs
    tmux
    tofrodos
    vim-X11
    vte3
    wget
    which
    xkeyboard-config
    xorg-x11-font-utils
    xorg-x11-fonts-100dpi
    xorg-x11-fonts-75dpi
    xorg-x11-fonts-ISO8859-1-100dpi
    xorg-x11-fonts-ISO8859-1-75dpi
    xorg-x11-fonts-ISO8859-14-100dpi
    xorg-x11-fonts-ISO8859-14-75dpi
    xorg-x11-fonts-ISO8859-15-75dpi
    xorg-x11-fonts-ISO8859-2-100dpi
    xorg-x11-fonts-ISO8859-2-75dpi
    xorg-x11-fonts-ISO8859-9-100dpi
    xorg-x11-fonts-ISO8859-9-75dpi
    xorg-x11-fonts-Type1
    xorg-x11-fonts-cyrillic
    xorg-x11-fonts-ethiopic
    xorg-x11-fonts-misc
    xterm
    xz-libs
    zlib-devel
)

eda_pip_packages=(
    boto3
    # pandas # Doesn't install on python2
    python-hostlist
    # virtualenv # Doesn't install on python2
)

eda_pip3_packages=(
    ${eda_pip_packages[@]}
    pandas
    requests
    virtualenv
)

eda_npm_packages=(
    ejs
    typescript
)

rc=0

$install_packages "yum list installed" "yum install -y" ${eda_yum_packages[@]}

PIP=pip2.7
$install_packages "$PIP show" "$PIP install" ${eda_pip_packages[@]}

PIP="python3 -m pip"
$install_packages "$PIP show" "$PIP install" ${eda_pip3_packages[@]}

npm install $(echo ${eda_npm_packages[*]})

if [ ! -e /usr/lib64/libreadline.so.5 ]; then
    ln -s /usr/lib64/libreadline.so.6 /usr/lib64/libreadline.so.5
fi

if [ ! -e /usr/lib64/libreadline.so.5 ]; then
    ln -s /usr/lib64/libreadline.so.6 /usr/lib64/libreadline.so.55
fi

if [ ! -e /usr/lib64/libncurses.so ]; then
    ln -s /usr/lib64/libncurses.so.5 /usr/lib64/libncurses.so
fi

mkdir -p /root/sem
touch /root/sem/eda-packages-installed

if [ $rc != "0" ]; then
    echo "error: Failed"
    exit $rc
fi
echo Passed
