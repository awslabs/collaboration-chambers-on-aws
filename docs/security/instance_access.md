---
title: Instance Access
---

Administrators can access instances using AWS Systems Manager Session Manager or using SSH to connect via
the network bastion.

### Instance Access Using Session Manager

Go to the EC2 console, right click on the instance and select **Connect**.
Select **Session Manager** and click **Connect**.
This will open a terminal in a browser tab as ssm-user which has sudo access on the instance.

If Session Manager cannot connect to the instance it may be a problem with the **amazon-ssm-agent** on the instance.
In that case you will have to connect to the instance using SSH via the bastion.

### Instance Access Using SSH

Only administrators that have the private key of the EC2 KeyPair can connect to the bastion using SSH.
The bastion host is in a private subnet behind a Network Load Balancer.
You can get the DNS name of the loadbalancer by looking at the BastionDnsName output of the CloudFormation stack.
You can also get the name using the AWS CLI.

```bastionDns=$(aws cloudformation describe-stacks --stack-name <stack-name> --query 'Stacks[*].Outputs[?OutputKey==`BastionDnsName`].OutputValue' --output text)```

You should connect to the bastion using agent forwarding so that you can ssh from the bastion to other instances in the VPC.

```ssh -A -i privatekey.pem ec2-user@$bastionDns```

On Windows you can use Pageant for agent forwarding. 
On linux systems the following command will load your private key.

```
ssh-add privatekey.pem
ssh -A ec2-user@$bastionDns
```

Once you are on the bastion you can ssh to any instance in the VPC.

```
ssh -A ec2-user@$bastionDns
ssh proxy.soca.local
```

You can configure ssh to automatically connect to another instance in the VPC via the bastion by adding
the following lines to you **~/.ssh/config**.

```
Host soca-*
     ForwardAgent yes
     User ec2-user
     ProxyJump ec2-user@<BastionDnsName>:22

Host soca-proxy
     Hostname proxy.soca.local
```

With that added to your SSH config you can connect to the proxy instance with one command.

```
ssh-add <pem-file>
ssh soca-proxy
```
