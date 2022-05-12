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

# User customization code below
