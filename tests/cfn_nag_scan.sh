#!/bin/bash -ex

# If CFN_NAG_SCAN is not installed on your system
# > https://github.com/stelligent/cfn_nag
#

scriptdir=$(dirname $(readlink -f $0))

# Validate CloudFormation templates
if ! cfn_nag_scan --version; then
    sudo gem install cfn-nag
fi
CFN_NAG_SCAN=$(which cfn_nag_scan)
CWD=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))

# Validate Docs and codebase
cd $CWD/../
$CFN_NAG_SCAN  -i $CWD/../source/scale-out-computing-on-aws.template --fail-on-warnings
$CFN_NAG_SCAN  -i $CWD/../source/install-with-existing-resources.template --fail-on-warnings
$CFN_NAG_SCAN  -i $CWD/../source/install-with-existing-vpc.template --fail-on-warnings
for template in $(ls $CWD/../source/templates);
    do
       $CFN_NAG_SCAN  -i $CWD/../source/templates/$template --fail-on-warnings
done
