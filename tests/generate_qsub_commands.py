# Note: AMIs are for us-west-2. Adjust if using different region (find AMIs on the primary template mapping)
distribution = {'amazonlinux2': 'ami-082b5a644766e0e6f',
                'centos7': 'ami-01ed306a12b7d1c96',
                'rhel7': 'ami-036affea69a1101c9'}

# S3 Bucket to mount on FSx. Make sure you DO have updated your IAM policy and added API permission to your bucket for the scheduler
fsx_s3_bucket = ''
fsx_dns = ''

for distro in distribution.keys():
    for k, ami_id in distribution.items():
        if k == distro:
            print("#============ " + distro + " ============ ")
            print('qsub -N ' + distro + '_efa -l instance_type=c5n.18xlarge -l efa_support=true -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /opt/amazon/efa/bin/fi_info -p efa')
            print('qsub -N ' + distro + '_root_scratch -l root_size=26 -l scratch_size=98 -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/df -h')
            print('qsub -N ' + distro + '_scratch_iops -l scratch_size=100 -l scratch_iops=3000 -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/df -h')

            print('qsub -N ' + distro + '_instance_store -l instance_type=m5ad.4xlarge -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/df -h')
            if fsx_s3_bucket != '':
                print('qsub -N ' + distro + '_fsx_ephemeral -l fsx_lustre_bucket=s3://'+fsx_s3_bucket+' -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/ls -ltr /fsx')

            if fsx_dns != '':
                print('qsub -N ' + distro + '_fsx_exising -l fsx_lustre_dns='+fsx_dns+' -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/ls -ltr /fsx')

            print('qsub -N ' + distro + '_ht_enabled -l instance_type=m5.4xlarge -l ht_support=true -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/lscpu --extended')
            print('qsub -N ' + distro + '_ht_disabled -l instance_type=m5.4xlarge -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/lscpu --extended')
            print('qsub -N ' + distro + '_spot_auto -l instance_type=t3.medium -l spot_price=auto -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/echo "Run on Scheduler: /bin/aws ec2 describe-spot-instance-requests --region=us-west-2"')
            print('qsub -N ' + distro + '_spot_fixed -l instance_type=m5.large -l spot_price=0.95 -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- /bin/echo "Run on Scheduler: /bin/aws ec2 describe-spot-instance-requests --region=us-west-2"')
            print('qsub -N ' + distro + '_spot_allocation l instance_type=r5.large -l nodes=5 -l spot_allocation_count=4 -l spot_price=auto -l instance_ami=' +ami_id + ' -l base_os=' + distro + ' -- echo "Run on Scheduler: /bin/aws ec2 describe-spot-instance-requests --region=us-west-2"')
