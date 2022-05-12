---
title: EC2 Image Builder
---

SOCA uses EC2 Image Builder Pipelines to automate the creation of custom AMIs.
By default it creates pipelines for four different CentOS 7 based AMIs.

* **CentOS 7 SOCA AMI**: Preinstalls the SOCA software
* **CentOS 7 SOCA Desktop**: Same as CentOS 7 SOCA AMI plus installs the DCV software for Linux Desktop instances.
* **CentOS 7 EDA AMI**: Same as CentOS 7 SOCA AMI plus installs packages required by EDA tools.
* **CentOS 7 SOCA Desktop**: Same as CentOS 7 EDA AMI plus installs the DCV software for Linux Desktop instances.

By default the pipelines are created and executed.
You can follow the *BuildUrl links in the stack outputs to get the status of the AMIs and the AMI IDs once the builds are complete.

It also has a pipeline that in the process of building the AMI creates a yum mirror and stores it in S3 and also saves the SOCA software in the same S3 bucket.

* **CentOS 7 MirrorRepos**: Creates yum repo mirror in S3 and mirrors source code required by SOCA in the same S3 bucket.

The S3 bucket and folder for the mirror are stored in Systems Manager Parameter Store with the following keys:

* /**StackName**/repositories/**distribution**/**date-timestamp**/RepositoryBucket
* /**StackName**/repositories/**distribution**/**date-timestamp**/RepositoryFolder
* /**StackName**/repositories/**distribution**/latest/RepositoryBucket
* /**StackName**/repositories/**distribution**/latest/RepositoryBucket

These SSM parameters can be passed as parameters to SOCA so that it uses the S3 repository instead of public mirrors off of the internet.
This allows you to use a stable version of the repos and also removes the requirement for internet access because the S3 bucket can
be accessed using a VPC Endpoint.

## Manually Running the Pipelines to Create the AMIs

You can also manually trigger the pipelines to create the AMIs.

### Running Pipelines Using the Console

Follow the *ImagePipelineUrl link in the stack outputs to go to the EC2 Image Builder pipeline.
From Actions select **Run Pipeline**.
This will trigger the pipeline and you can monitor it's progress by selecting **Images** on the left.

### Running Pipelines Using the AWS CLI

Go to the CloudFormation console and the Outputs tab of your SOCA stack.
The command to manually run the pipelines are in the outputs.

### Monitoring Pipeline Builds

Go to the EC2 Image Builder console, select **Image Pipelines**, and select a pipeline to see it's output images.

## Debug

By default, the pipelines are configured to terminate the build instance if a build fails.
Unfortunately, this can make debug difficult.
The logs are stored in S3, but the names are difficult to find.
Debug is easier if you change the **TerminateBuildInstanceOnFailure** parameter to **false** so that the instance is left running after a failed build.
Then you can easily see the output in `/var/log/messages`

```
grep ImageBuilder /var/log/messages | less
```
