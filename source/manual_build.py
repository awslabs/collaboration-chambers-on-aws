#!/usr/bin/env python3

import datetime as dt
from datetime import datetime
import fileinput
import logging
import os
import random
import re
import shutil
import string
import sys
import argparse
from shutil import make_archive, copy, copytree
from time import sleep

def upload_objects(s3, bucket_name, s3_prefix, directory_name):
    try:
        my_bucket = s3.Bucket(bucket_name)
        for path, subdirs, files in os.walk(directory_name):
            path = path.replace("\\", "/")
            directory = path.replace(directory_name.replace("\\", "/"), "")
            for file in files:
                print("%s[+] Uploading %s to s3://%s/%s%s%s" % (fg('green'), os.path.join(path, file), bucket_name, s3_prefix, directory+'/'+file, attr('reset')))
                my_bucket.upload_file(os.path.join(path, file), s3_prefix+directory+'/'+file)

    except Exception as err:
        print(err)


def get_input(prompt):
    if sys.version_info[0] >= 3:
        response = input(prompt)
    else:
        # Python 2
        response = raw_input(prompt)
    return response

if __name__ == "__main__":
    try:
        from colored import fg, bg, attr
        import boto3
        from requests import get
        import requests.exceptions
        from botocore.client import ClientError
        from botocore.exceptions import ProfileNotFound
    except ImportError as e:
        print(e)
        print(" > You must have , 'colored', 'boto3' and 'requests' installed. Run 'pip install boto3 colored requests massedit' or 'pip install -r requirements.txt' first")
        exit(1)

    if os.name == "nt":
        print("%sSorry, Windows builds are currently not supported. Please use a UNIX system if you want to do a custom build\n%s" % (fg('yellow'), attr('reset')))
        print("%s=== How to install SOCA on Windows ===%s" % (fg('yellow'), attr('reset')))
        print("%s1 - Download the latest release (RELEASE-<version>.tar.gz) from https://github.com/awslabs/scale-out-computing-on-aws/releases%s" % (fg('yellow'), attr('reset')))
        print("%s2 - Install SOCA via https://awslabs.github.io/scale-out-computing-on-aws/install-soca-cluster/#option-2-download-the-latest-release-targz%s"  % (fg('yellow'), attr('reset')))
        exit(1)

    parser = argparse.ArgumentParser(description='Build & Upload SOCA CloudFormation resources.')
    parser.add_argument('--profile', '-p', type=str, help='AWS CLI profile to use. See https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html')
    parser.add_argument('--region', '-r', type=str, help='AWS region to use. If not specified will be prompted.')
    parser.add_argument('--bucket', '-b', type=str, help='S3 Bucket to use. If not specified will be prompted.')
    parser.add_argument('--stack-name', '-s', type=str, help='Stack name to deploy in quick create link.')
    parser.add_argument('--VpcCidr', type=str, help='Value for VpcCidr parameter.')
    parser.add_argument('--vpc-id', type=str, help='Id of existing VPC.')
    parser.add_argument('--public-subnet1', type=str, help='Pubic Subnet1 of existing VPC.')
    parser.add_argument('--public-subnet2', type=str, help='Pubic Subnet2 of existing VPC.')
    parser.add_argument('--public-subnet3', type=str, help='Pubic Subnet3 of existing VPC.')
    parser.add_argument('--private-subnet1', type=str, help='Private Subnet1 of existing VPC.')
    parser.add_argument('--private-subnet2', type=str, help='Private Subnet2 of existing VPC.')
    parser.add_argument('--private-subnet3', type=str, help='Private Subnet3 of existing VPC.')
    parser.add_argument('--nat-ip-address', type=str, help='NAT ip address of existing VPC for security groups')
    parser.add_argument('--PublicVpc', type=str, default="true", help='Whether VPC has public subnets and internet access.')
    parser.add_argument('--SocaLocalDomain', type=str, help='Domain for Route53 private hosted zone')
    parser.add_argument('--prefix-list-id', '--pl', type=str, help='Prefix list for ingress.')
    parser.add_argument('--ssh-keypair', type=str, help='SSH keypair.')
    parser.add_argument('--username', type=str, help='Username')
    parser.add_argument('--password-parameter', type=str, help='SSM Parameter name with password')
    parser.add_argument('--email', type=str, help='Email for errors')
    parser.add_argument('--RepositoryBucket', type=str, help='Value for RepositoryBucket parameter.')
    parser.add_argument('--RepositoryFolder', type=str, help='Value for RepositoryFolder parameter.')
    parser.add_argument('--CustomAMI', type=str, help='Custom AMI for compute nodes.')
    parser.add_argument('--BaseOS', type=str, help='Base OS of custom AMI.')
    parser.add_argument('--id', type=str, help='Unique id for the s3 bucket folder. Use to update existing build.')
    parser.add_argument('--create', action='store_true', default=False, help='Create new SOCA cluster.')
    parser.add_argument('--create-change-set', action='store_true', default=False, help='Create CloudFormation changeset.')
    parser.add_argument('--update', action='store_true', default=False, help='Create CloudFormation changeset and execute it.')
    args = parser.parse_args()

    print("====== Parameters ======\n")
    if not args.region:
        region = get_input(" > Please enter the AWS region you'd like to build SOCA in: ")
    else:
        region = args.region
    if not args.bucket:
        bucket = get_input(" > Please enter the name of an S3 bucket you own: ")
    else:
        bucket = args.bucket

    s3_bucket_exists = False
    try:
        print(" > Validating you can have access to that bucket...")
        if args.profile:
            try:
                session = boto3.session.Session(profile_name=args.profile)
                s3 = session.resource('s3', region_name=region)
            except ProfileNotFound:
                print("%s> Profile %s not found. Check ~/.aws/credentials file.%s" % (fg('red'), args.profile, attr('reset')))
                exit(1)

        else:
            s3 = boto3.resource('s3', region_name=region)
        s3.meta.client.head_bucket(Bucket=bucket)
        s3_bucket_exists = True
    except ClientError as e:
        print("%s > The bucket %s does not exist or you have no access.%s" % (fg('red'), bucket, attr('reset')))
        print("%s %s %s" % (fg('red'), e, attr('reset')))
        print("%s> Building locally but not uploading to S3%s"  % (fg('yellow'), attr('reset')))

    # Detect Client IP
    try:
        get_client_ip = get("https://ifconfig.co/json",)
        if get_client_ip.status_code == 200:
            client_ip = get_client_ip.json()['ip'] + '/32'
        else:
            client_ip = ''
    except requests.exceptions.RequestException as e:
        print("Unable to determine client IP")
        client_ip = ''

    build_path = os.path.dirname(os.path.realpath(__file__))
    os.chdir(build_path)
    # Make sure build ID is > 3 chars and does not start with a number
    if args.id:
        unique_id = args.id
    else:
        unique_id = ''.join(random.choice(string.ascii_lowercase) + random.choice(string.digits) for i in range(2))
    build_folder = 'dist/' + unique_id
    if os.path.exists(build_folder):
        shutil.rmtree(build_folder)
    output_prefix = "soca-installer-" + unique_id  # prefix for the output artifact
    print("====== SOCA Build ======\n")
    print(" > Generated unique ID for build: " + unique_id)
    print(" > Creating temporary build folder ... ")
    print(" > Copying required files ... ")
    targets = ['playbooks', 'scripts', 'templates', 'README.txt', 'scale-out-computing-on-aws.template', 'install-with-existing-resources.template', 'install-with-existing-vpc.template.yml']
    for target in targets:
        if os.path.isdir(target):
            copytree(target, build_folder + '/' + target)
        else:
            copy(target, build_folder + '/' + target)
    make_archive(build_folder + '/soca', 'gztar', 'soca')

    # Replace Placeholder
    for line in fileinput.input([build_folder + '/scale-out-computing-on-aws.template', build_folder + '/install-with-existing-resources.template', build_folder + '/install-with-existing-vpc.template.yml'], inplace=True):
        print(line.replace('%%BUCKET_NAME%%', 'your-s3-bucket-name-here').replace('%%SOLUTION_NAME%%/%%VERSION%%', 'your-s3-folder-name-here').replace('\n', ''))

    print(" > Creating archive for build id: " + unique_id)
    make_archive('dist/' + output_prefix, 'gztar', build_folder)

    if s3_bucket_exists:
        print("====== Upload to S3 ======\n")
        print(" > Uploading required files ... ")
        upload_objects(s3, bucket, output_prefix, build_path + "/" + build_folder)

        # CloudFormation Template URL
        base_template_url = "https://%s.s3.amazonaws.com/%s" % (bucket, output_prefix)
        template_url = base_template_url + "/scale-out-computing-on-aws.template"
        existing_resources_template_url = base_template_url + "/install-with-existing-resources.template"
        existing_vpc_template_url = base_template_url + "/install-with-existing-vpc.template.yml"
        if args.vpc_id:
            template_url = existing_vpc_template_url
            print(f"\nInstalling into existing VPC: {args.vpc_id}")

        collaboration_top_template_url = base_template_url + "/templates/CollaborationVpcEndpointTop.template"
        collaboration_nested_template_url = base_template_url + "/templates/CollaborationVpcEndpointNested.template"
        image_builder_template_url = base_template_url + "/templates/ImageBuilder.template"

        params = ''
        if args.stack_name:
            params += '&StackName=' + args.stack_name

        params += '&param_S3InstallBucket=%s&param_S3InstallFolder=%s' % (bucket, output_prefix)

        params += '&param_ClientIp=' + client_ip

        if args.vpc_id:
            params += '&param_VpcId=' + args.vpc_id
            # Check to see if VPC endpoints exist
            ec2_client = boto3.client('ec2', region_name=region)
            has_s3_endpoint = False
            has_ec2_endpoint = False
            vpc_endpoint_services = []
            for page in ec2_client.get_paginator('describe_vpc_endpoints').paginate(Filters=[{'Name': 'vpc-id', 'Values':[args.vpc_id]}]):
                for vpc_endpoint_dict in page['VpcEndpoints']:
                    service_name = vpc_endpoint_dict['ServiceName']
                    service = service_name.split('.')[-1]
                    #print(f"{service} VPC endpoint exists")
                    vpc_endpoint_services.append(service)
                    if service == 's3':
                        has_s3_endpoint = True
                    elif service == 'ec2':
                        has_ec2_endpoint = True
            if has_s3_endpoint:
                print("\nS3 VPC Endpoint already exists so not creating")
                params += '&param_CreateS3VpcEndpoint=false'
            if has_ec2_endpoint:
                print("\nEC2 VPC Endpoint already exists so not creating VPC endpoints")
                params += '&param_CreateVpcEndpoints=false'

        if args.public_subnet1:
            params += '&param_PublicSubnet1=' + args.public_subnet1
        if args.public_subnet2:
            params += '&param_PublicSubnet2=' + args.public_subnet2
        if args.public_subnet3:
            params += '&param_PublicSubnet3=' + args.public_subnet3
        if args.private_subnet1:
            params += '&param_PrivateSubnet1=' + args.private_subnet1
        if args.private_subnet2:
            params += '&param_PrivateSubnet2=' + args.private_subnet2
        if args.private_subnet3:
            params += '&param_PrivateSubnet3=' + args.private_subnet3

        if args.nat_ip_address:
            params += '&param_EIPNat=' + args.nat_ip_address

        if args.prefix_list_id:
            params += '&param_PrefixListId=' + args.prefix_list_id

        if args.ssh_keypair:
            params += '&param_SSHKeyPair=' + args.ssh_keypair

        if args.SocaLocalDomain:
            params += '&param_SocaLocalDomain=' + args.SocaLocalDomain

        if args.username:
            params += '&param_UserName=' + args.username

        if args.password_parameter:
            params += '&param_UserPasswordSsmParameterName=' + args.password_parameter

        if args.email:
            params += '&param_ErrorSnsTopicEmail=' + args.email

        print("\n====== Upload COMPLETE ======")
        print("\ntemplate URL:\n" + template_url)
        print("\nCollaboration VPC endpoint template URLs:")
        print(collaboration_top_template_url)
        print(collaboration_nested_template_url)
        print("\nImageBuilder template URL:\n" + image_builder_template_url)
        print("\n====== Installation Instructions ======")
        print("1. Click on the following link:")
        print("%s==> https://console.aws.amazon.com/cloudformation/home?region=%s#/stacks/create/review?&templateURL=%s%s%s\n" % (fg('light_blue'), region, template_url, params, attr('reset')))
        print("%s==> https://console.aws.amazon.com/cloudformation/home?region=%s#/stacks/create/review?&templateURL=%s%s%s\n" % (fg('light_blue'), region, existing_resources_template_url, params, attr('reset')))
        print("%s==> https://console.aws.amazon.com/cloudformation/home?region=%s#/stacks/create/review?&templateURL=%s%s%s\n" % (fg('light_blue'), region, existing_vpc_template_url, params, attr('reset')))

        print("2. The 'Install Location' parameters are pre-filled for you, fill out the rest of the parameters.")

        print("\nTo create VPC endpoint to connect to another SOCA cluster click on the following link if you own the collaboration stack:")
        print("%s==> https://console.aws.amazon.com/cloudformation/home?region=%s#/stacks/create/review?&templateURL=%s&StackName=%s-%s&param_SocaStackname=%s&param_CollaborationSocaStackname=%s%s" % (fg('light_blue'), region, collaboration_top_template_url, args.stack_name, "collab", args.stack_name, "collab", attr('reset')))

        print("\nTo create VPC endpoint to connect to another SOCA cluster click on the following link if you do not own the collaboration stack:")
        print("%s==> https://console.aws.amazon.com/cloudformation/home?region=%s#/stacks/create/review?&templateURL=%s&StackName=%s-%s&param_SocaStackname=%s&param_CollaborationSocaStackname=%s%s" % (fg('light_blue'), region, collaboration_nested_template_url, args.stack_name, "collab", args.stack_name, "collab", attr('reset')))

        if args.create or args.create_change_set or args.update:
            cfn_client = boto3.client('cloudformation', region_name=region)
            parameters = [
                {'ParameterKey': 'S3InstallBucket', 'ParameterValue': args.bucket},
                {'ParameterKey': 'S3InstallFolder', 'ParameterValue': output_prefix},
            ]

            if args.create_change_set or args.update:
                parameters.append({'ParameterKey': 'BaseOS', 'UsePreviousValue': True})
                parameters.append({'ParameterKey': 'CustomAMI', 'UsePreviousValue': True})
                parameters.append({'ParameterKey': 'SchedulerInstanceType', 'UsePreviousValue': True})

            if args.VpcCidr:
                parameters.append({'ParameterKey': 'VpcCidr', 'ParameterValue': args.VpcCidr})
            elif not args.create:
                parameters.append({'ParameterKey': 'VpcCidr', 'UsePreviousValue': True})

            if args.PublicVpc:
                parameters.append({'ParameterKey': 'PublicVpc', 'ParameterValue': args.PublicVpc})
            elif not args.create:
                parameters.append({'ParameterKey': 'PublicVpc', 'UsePreviousValue': True})

            parameters.append({'ParameterKey': 'ClientIp', 'ParameterValue': client_ip})

            if args.vpc_id:
                parameters.append({'ParameterKey': 'VpcId', 'ParameterValue': args.vpc_id})
                if has_s3_endpoint:
                    parameters.append({'ParameterKey': 'CreateS3VpcEndpoint', 'ParameterValue': 'false'})
                if has_ec2_endpoint:
                    parameters.append({'ParameterKey': 'CreateVpcEndpoints', 'ParameterValue': 'false'})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'VpcId', 'UsePreviousValue': True})

            if args.public_subnet1:
                parameters.append({'ParameterKey': 'PublicSubnet1', 'ParameterValue': args.public_subnet1})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'PublicSubnet1', 'UsePreviousValue': True})

            if args.public_subnet2:
                parameters.append({'ParameterKey': 'PublicSubnet2', 'ParameterValue': args.public_subnet2})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'PublicSubnet2', 'UsePreviousValue': True})

            if args.public_subnet3:
                parameters.append({'ParameterKey': 'PublicSubnet3', 'ParameterValue': args.public_subnet3})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'PublicSubnet3', 'UsePreviousValue': True})

            if args.private_subnet1:
                parameters.append({'ParameterKey': 'PrivateSubnet1', 'ParameterValue': args.private_subnet1})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'PrivateSubnet1', 'UsePreviousValue': True})

            if args.private_subnet2:
                parameters.append({'ParameterKey': 'PrivateSubnet2', 'ParameterValue': args.private_subnet2})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'PrivateSubnet2', 'UsePreviousValue': True})

            if args.private_subnet3:
                parameters.append({'ParameterKey': 'PrivateSubnet3', 'ParameterValue': args.private_subnet3})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'PrivateSubnet3', 'UsePreviousValue': True})

            if args.nat_ip_address:
                parameters.append({'ParameterKey': 'NatEIP1', 'ParameterValue': args.nat_ip_address})
            #elif not args.create:
            #    parameters.append({'ParameterKey': 'NatEIP1', 'UsePreviousValue': True})

            if args.prefix_list_id:
                parameters.append({'ParameterKey': 'PrefixListId', 'ParameterValue': args.prefix_list_id})
            elif not args.create:
                parameters.append({'ParameterKey': 'PrefixListId', 'UsePreviousValue': True})

            if args.ssh_keypair:
                parameters.append({'ParameterKey': 'SSHKeyPair', 'ParameterValue': args.ssh_keypair})
            elif not args.create:
                parameters.append({'ParameterKey': 'SSHKeyPair', 'UsePreviousValue': True})

            if args.SocaLocalDomain:
                parameters.append({'ParameterKey': 'SocaLocalDomain', 'ParameterValue': args.SocaLocalDomain})
            elif not args.create:
                parameters.append({'ParameterKey': 'SocaLocalDomain', 'UsePreviousValue': True})

            if args.username:
                parameters.append({'ParameterKey': 'UserName', 'ParameterValue': args.username})
            elif not args.create:
                parameters.append({'ParameterKey': 'UserName', 'UsePreviousValue': True})

            if args.password_parameter:
                parameters.append({'ParameterKey': 'UserPasswordSsmParameterName', 'ParameterValue': args.password_parameter})
            elif not args.create:
                parameters.append({'ParameterKey': 'UserPasswordSsmParameterName', 'UsePreviousValue': True})

            if args.email:
                parameters.append({'ParameterKey': 'ErrorSnsTopicEmail', 'ParameterValue': args.email})
            elif not args.create:
                parameters.append({'ParameterKey': 'ErrorSnsTopicEmail', 'UsePreviousValue': True})

            if args.RepositoryBucket:
                parameters.append({'ParameterKey': 'RepositoryBucket', 'ParameterValue': args.RepositoryBucket})
            elif not args.create:
                parameters.append({'ParameterKey': 'RepositoryBucket', 'UsePreviousValue': True})
            if args.RepositoryFolder:
                parameters.append({'ParameterKey': 'RepositoryFolder', 'ParameterValue': args.RepositoryFolder})
            elif not args.create:
                parameters.append({'ParameterKey': 'RepositoryFolder', 'UsePreviousValue': True})
            if args.CustomAMI:
                parameters.append({'ParameterKey': 'CustomAMI', 'ParameterValue': args.CustomAMI})
            elif not args.create:
                parameters.append({'ParameterKey': 'CustomAMI', 'UsePreviousValue': True})
            if args.BaseOS:
                parameters.append({'ParameterKey': 'BaseOS', 'ParameterValue': args.BaseOS})
            elif not args.create:
                parameters.append({'ParameterKey': 'BaseOS', 'UsePreviousValue': True})

        if args.create:
            print("\nCreating new stack: {}".format(args.stack_name))
            cfn_client.create_stack(
                StackName=args.stack_name,
                TemplateURL=template_url,
                Parameters=parameters,
                DisableRollback = True,
                Capabilities=['CAPABILITY_IAM', 'CAPABILITY_AUTO_EXPAND'],
            )

        elif args.create_change_set or args.update:
            now = datetime.now(dt.timezone.utc)
            changeSetName = '{}-update-{}'.format(args.stack_name, now.strftime('%y%m%d%H%M%S'))
            cfn_client.create_change_set(
                StackName=args.stack_name,
                TemplateURL=template_url,
                Capabilities=['CAPABILITY_IAM', 'CAPABILITY_AUTO_EXPAND'],
                ChangeSetName=changeSetName,
                Parameters=parameters,
            )
            print("\nCreated CloudFormation change set: {}".format(changeSetName))
            status = 'CREATE_PENDING'
            while status != 'CREATE_COMPLETE':
                print("\nWaiting 15s for change set to be created")
                sleep(15)
                try:
                    status = cfn_client.describe_change_set(StackName=args.stack_name, ChangeSetName=changeSetName)['Status']
                except ClientError as e:
                    logging.exception("Could not describe change set. Add cloudformation:DescribeChangeSet to your IAM role?")
                    raise

        if args.update:
            print("\nExecuting {}".format(changeSetName))
            cfn_client.execute_change_set(
                ChangeSetName=changeSetName,
                StackName=args.stack_name,
                # Resources can't be replaced when DisableRollback is set on updates
                #DisableRollback = True,
            )
    else:
        print("\n====== Installation Instructions ======")
        print("1: Create or use an existing S3 bucket on your AWS account (eg: 'mysocacluster')")
        print("2: Drag & Drop " + build_path + "/" + build_folder + " to your S3 bucket (eg: 'mysocacluster/" + build_folder + ")")
        print("3: Launch CloudFormation and use scale-out-computing-on-aws.template as base template")
        print("4: Enter your cluster information.")

    print("\n\nFor more information: https://awslabs.github.io/scale-out-computing-on-aws/install-soca-cluster/")
