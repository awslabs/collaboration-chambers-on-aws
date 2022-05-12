#!/bin/bash
/usr/bin/curl https://cloudformation.{{Region}}.amazonaws.com && \
    aws cloudwatch put-metric-data --namespace 'Proxy' --metric-name 'Available' --value 1 --region ${AWS::Region} || \
    aws cloudwatch put-metric-data --namespace 'Proxy' --metric-name 'Available' --value 0 --region ${AWS::Region}
