---
title: Create Private Yum Repos
---

If security requires no internet access then you need a way to install and update packages.
In this scenario you should deploy the MirrorRepos stack before deploying SOCA.

Create an S3 bucket in the same region where you will deploy SOCA.
Download the SOCA package and change to the MirrorRepos directory.
Then deploy the stack using the S3 bucket you created.

```
cd  Solution-for-scale-out-computing-on-aws/source/MirrorRepos
make STACK_NAME=MirrorRepos S3_MIRROR_REPO_BUCKET=<bucket-name> S3_MIRROR_REPO_FOLDER=repositories upload create
```

This stack uses Amazon CodeBuild to copy the source code that SOCA uses and the CentOS 7 repos into your S3
bucket where it can be used by your SOCA cluster.
You can monitor the status of the process by going to the outputs of your stack and clicking on the 
MirrorCentos7ReposBuildUrl output.
When the build completes the S3 path of the mirror will be at the end of the logs and you will
use that as the RepositoryBucket and RepositoryFolder parameters of the SOCA stack when you deploy
it.
This will configure SOCA to use your private S3 mirror instead of public repositories.
