#!/usr/bin/env python3

import boto3
import logging
from logging import INFO, DEBUG
from os import path
from os import system
import pprint
from subprocess import check_output
import sys

logging.basicConfig(level=INFO)
#logging.basicConfig(level=DEBUG)
pp = pprint.PrettyPrinter()

rc = 0
try:
    # Get VPC id so can mount on FSX file systems for that VPC
    region = check_output(['curl', '-s', 'http://169.254.169.254/latest/meta-data/placement/region'], encoding='UTF-8')
    instance_id = check_output(['curl', '-s', 'http://169.254.169.254/latest/meta-data/instance-id'], encoding='UTF-8')
    logging.debug("instance_id={}".format(instance_id))
    ec2_client = boto3.client('ec2', region_name=region)
    vpcId = ''
    try:
        vpcId = ec2_client.describe_instances(InstanceIds=[instance_id])['Reservations'][0]['Instances'][0]['VpcId']
    except:
        logging.error("Could not get VpcId for {}".format(instance_id))
        exit(1)
    logging.debug(vpcId)
    fsx_client = boto3.client('fsx', region_name=region)
    fileSystems = fsx_client.describe_file_systems()['FileSystems']
    logging.debug(pp.pformat(fileSystems))
    for fileSystem in fileSystems:
        logging.debug(pp.pformat(fileSystem))
        if fileSystem['VpcId'] != vpcId:
            continue
        status = fileSystem['Lifecycle']
        if status != "AVAILABLE":
            continue
        mountpoint = ''
        options = 'noatime,flock'
        for tag in fileSystem['Tags']:
            if tag['Key'] == 'mountpoint':
                mountpoint = tag['Value']
            if tag['Key'] == 'options':
                options = tag['Value']
        if not mountpoint:
            continue
        dnsName = fileSystem['DNSName']
        mountName = fileSystem['LustreConfiguration']['MountName']
        if not path.exists(mountpoint):
            if system("mkdir {}".format(mountpoint)) != 0:
                logging.error("Could not create {}".format(mountpoint))
                rc = 1
                continue
        system("umount {}".format(mountpoint))
        logging.info('mounting {} at {}'.format(dnsName, mountpoint))
        cmd = "mount -t lustre -o {} {}@tcp:/{} /fsx ".format(options, dnsName, mountName)
        logging.info(cmd)
        if system(cmd) != 0:
            logging.error("Mount of {} failed".format(mountpoint))
            rc = 1
except:
    logging.exception("Unhandled exception")
    rc = 1
if rc:
    logging.error('Failed')
else:
    logging.info('Passed')
sys.exit(rc)
