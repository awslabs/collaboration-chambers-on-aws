#!/bin/bash -xe

scriptdir=$(dirname $(readlink -f $0))
source $scriptdir/config.sh

make update
