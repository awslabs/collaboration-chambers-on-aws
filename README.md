# Collaboration Chambers on AWS

A collaboration chamber is a compute environment configured to allow collaboration with third parties and secure
the IP inside the environment so that it can only be accessed by approved parties and so that the IP can be
secured from egress from the environment.

This implementation is based on [Scale Out Computing on AWS](https://github.com/awslabs/scale-out-computing-on-aws), an official AWS solution.
It adds additional security features required to enable secure collaboration.
Some of the key security changes include:

* Block user ssh access to the VPC.
* Require all internet access to go through a proxy.
* Use AWS VPC endpoints for all service access
* Enable a completely private VPC with no internet access
* Add egress rules to all security groups

## Deployment

If your account is new, then you may need to go to the Service Quotas console
and increase the limits for your on-demand general purpose EC2 instances.

Clone this repository.

Configure your AWS credentials.
The installer uses the AWS API to deploy infrastructure on AWS using CloudFormation.
This requires administrative credentials to create all of the required AWS resources.

Create an S3 bucket that will be used for deployment.

Create a prefix list that contains the CIDRs that should have access to the collaboration chamber.

Create a Systems Managers Parameter Store parameter with the password of the admin user.

```
cd source
stack_name=STACK_NAME
./manual_build.py \
    --stack-name $stack_name \
    --id stack_name \
    --region REGION \
    --bucket BUCKET \
    --prefix-list-id PREFIX_LIST_ID \
    --ssh-keypair SSH_KEYPAIR \
    --username USERNAME \
    --password-parameter PASSWORD_PARAMETER \
    --create
```

This will create a collaboration chamber with a public endpoint for the Web UI.

To create a collaboration chamber with no public access you will need to first create an S3 repository
that contains all of the software and also has an S3 yum repository for installing packages.
This is done my the ImageBuilder add on.

First edit collaboration-chambers-on-aws/add-ons/ImageBuilder/config.sh and set the values of all of the
variables.

```
export STACK_NAME=SocaImageBuilder

export AWS_DEFAULT_REGION=us-east-1
export SSH_KEY_PAIR=admin-us-east-1
export TerminateBuildInstanceOnFailure=false
#export TerminateBuildInstanceOnFailure=true
#export SNS_ERROR_TOPIC_ARN=""

export S3_IMAGE_BUILDER_BUCKET=my-bucket-${AWS_DEFAULT_REGION}
export S3_IMAGE_BUILDER_FOLDER=ImageBuilder/${STACK_NAME}
export S3_REPOSITORY_BUCKET=${S3_IMAGE_BUILDER_BUCKET}
export S3_REPOSITORY_FOLDER=repositories
```

```
cd collaboration-chambers-on-aws/add-ons/ImageBuilder
./create.sh
```

This will create a CloudFormation stack that will create a VPC that is used by EC2 ImageBuilder to build AMIs for SOCA and also
to create the repositories.
The outputs of the stack contain links to the image builder pipelines and builds.

A new collaboration chamber can now be created that doesn't have a public vpc.

```
cd source
stack_name=STACK_NAME
./manual_build.py \
    --stack-name $stack_name \
    --id stack_name \
    --region REGION \
    --bucket BUCKET \
    --prefix-list-id PREFIX_LIST_ID \
    --ssh-keypair SSH_KEYPAIR \
    --username USERNAME \
    --password-parameter PASSWORD_PARAMETER \
    --public-vpc false \
    --RepositoryBucket REPOSITORYBUCKET \
    --RepositoryFolder REPOSITORYFOLDER \
    --create
```




## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.
