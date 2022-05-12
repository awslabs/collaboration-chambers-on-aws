# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Initially, the version numbering will track those of Scale Out Computing on AWS (SOCA).

## [2.6.tbd] - 2021-04-30
### Added
- Support for Graviton2 instances
- Ability to disable web APIs via @disabled decorator

### Changed
- Instances with NVME instance store don't become unresponsive post-restart due to filesystem checks enforcement
- ElasticSearch is now deployed in private subnets

## [2.6.1] - 2021-01-20
### Added
- Added Name tag to EIPNat in Network.template
- Added support for Milan and Cape Town
- EBS volumes provisioned for DCV sessions (Windows/Linux) are now tagged properly

### Changed
- Updated EFA to 1.11.1
- Updated Python 3.7.1 to Python 3.7.9
- Update DCV version to 2020.2
- Updated awscli, boto3, and botocore to support instances announced at Re:Invent 2020
- Use new gp3 volumes instead of gp2 since they're more cost effective and provide 3000 IOPS baseline
- Removed SchedulerPublicIPAllocation from Scheduler.template as it's no longer used
- Updated CentOS, ALI2 and RHEL76 AMI IDs
