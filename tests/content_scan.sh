#!/bin/bash -ex

# If Viperlight is not installed on your system:
# > wget https://s3.amazonaws.com/viperlight-scanner/latest/viperlight.zip
# > unzip viperlight.zip
# > ./install.sh (require npm)
# > also install https://github.com/PyCQA/bandit (pip install bandit)

# If CFN_NAG_SCAN is not installed on your system
# > https://github.com/stelligent/cfn_nag
#
# netcat provides nc
#
# blc: Broken link checker?
# sudo npm install -g broken-link-checker

scriptdir=$(dirname $(readlink -f $0))

# Validate CloudFormation templates
if ! cfn_nag_scan --version; then
    sudo gem install cfn-nag
fi
CFN_NAG_SCAN=$(which cfn_nag_scan)
CWD=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))

# Validate Docs and codebase
cd $CWD/../

#VIPERLIGHT=$(which viperlight)
#viperlight scan

rm -f $scriptdir/cfn_nag_scan.log
$CFN_NAG_SCAN  -i $CWD/../source/scale-out-computing-on-aws.template --fail-on-warnings >> $scriptdir/cfn_nag_scan.log 2>&1
$CFN_NAG_SCAN  -i $CWD/../source/install-with-existing-resources.template --fail-on-warnings >> $scriptdir/cfn_nag_scan.log 2>&1
for template in $(ls $CWD/../source/templates);
    do
       $CFN_NAG_SCAN  -i $CWD/../source/templates/$template --fail-on-warnings >> $scriptdir/cfn_nag_scan.log 2>&1
done

# Dead Links checkers. Mkdocs must be up and running
MKDOCS_URL="127.0.0.1"
MCDOCS_PORT="8000"
MKDOCS_PROTOCOL="http://"
#nc -c $MKDOCS_URL $MCDOCS_PORT
if [[ $? -eq 1 ]];
  then
    echo "Documentation HTTP server is not running, please launch it first via mkdocs serve."
    exit 1
fi
blc $MKDOCS_PROTOCOL$MKDOCS_URL:$MCDOCS_PORT -ro

if [ ! -e $scriptdir/ScoutSuite ]; then
    git clone https://github.com/nccgroup/ScoutSuite
    cd $scriptdir/ScoutSuite
    python3 -m venv scoutesuite-venv
    source scoutesuite-venv/bin/activate
    python3 -m pip install -r requirements.txt
fi
cd $scriptdir/ScoutSuite
source scoutesuite-venv/bin/activate
python scout.py aws -r us-east-1
