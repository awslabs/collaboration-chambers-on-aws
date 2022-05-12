#!/bin/bash

installed_cmd=$1
install_cmd=$2
shift 2
already_installed_packages=( )
installed_packages=( )
failed=0
failed_packages=( )
for package in $@; do
    if $installed_cmd $package &> /dev/null; then
        echo "Already installed $package"
        already_installed_packages+=( $package )
    else
        echo "Installing $package"
        echo "$install_cmd $package"
        if ! $install_cmd $package; then
            echo "error: Install of $package failed"
            failed_packages+=( $package )
            failed=1
            rc=1
        else
            echo "Installed $package"
            installed=1
            installed_packages+=( $package )
        fi
    fi
done
echo ""
if [ ${#already_installed_packages[@]} -ne 0 ]; then
    echo "${#already_installed_packages[@]} package(s) already installed"
    for package in ${already_installed_packages[@]}; do
        echo "already installed $package"
    done
else
    echo "No package already installed"
fi
echo ""
if [ ${#installed_packages[@]} -ne 0 ]; then
    echo "${#installed_packages[@]} package(s) installed"
    for package in ${installed_packages[@]}; do
        echo "$package installed"
    done
else
    echo "No package installed"
fi
echo ""
if [ ${#failed_packages[@]} -ne 0 ]; then
    echo "error: ${#failed_packages[@]} package(s) failed to install"
    for package in ${failed_packages[@]}; do
        echo "error: $package failed to install"
    done
else
    echo "No package installs failed"
fi
exit $failed
