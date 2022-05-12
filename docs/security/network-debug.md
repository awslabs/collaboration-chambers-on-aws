---
title: Network Debug
---

Scale-Out Computing on AWS configures all security groups (firewalls) and the internet proxy
using the principal of least privilege.
This means that all network traffic is restricted unless specifically allowed by the
security groups (firewalls) and internet proxy.
If you suspect that traffic is being blocked that should be allowed then you can debug
network traffic using CloudWatch VPC flow logs and proxy logs.

### Proxy Access Log

Connect to the proxy server using Systems Manager or SSH and search `/var/log/squid/access.log` for
the string **DENIED**.
The log will show the time, the source IP address and the destination.

### VPC Flow Logs

The easiest way to debug network traffic that is blocked by security groups is to
search the VPC flow logs using CloudWatch Insights.

Go to the [CloudWatch Logs Insights](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:logs-insights)
console. Select the region where your cluster is deployed and select it's VPC Flow Logs group.
Update the query to select the packets you are interested in and run the query.
The following shows example of the query syntax.

```
fields @timestamp, srcAddr, srcPort, dstAddr, dstPort, action
| sort @timestamp desc
| filter action="REJECT"
#| filter srcPort="443"
#| filter dstPort="443"
#| filter dstAddr like "10.0."
#| filter dstAddr="10.0.169.50"
#| filter srcAddr="10.0.22.9" or dstAddr="10.0.175.175"
```