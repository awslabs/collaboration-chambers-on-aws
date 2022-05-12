#!/bin/bash -ex
# Configure the proxy server
# This is called by the ansible playbook.

set -ex

source /etc/environment

SERVER_IP=$(hostname -I | tr -d '[:space:]')

# Add a DNS entry to Route53 for the proxy
rm -f /tmp/route53.json
cat <<EOF >>/tmp/route53.json
{
    "Comment": "Update proxy record",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "proxy.${SOCA_LOCAL_DOMAIN}",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [{"Value": "${SERVER_IP}"}]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $SOCA_HOSTED_ZONE_ID --change-batch file:///tmp/route53.json
