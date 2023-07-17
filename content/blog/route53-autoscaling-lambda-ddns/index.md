---
title: Using Route53 to load balance autoscaling groups
date: "2023-07-11T18:21z"
description: "Using Route53 to create a DDNS service with Lambda for autoscaling groups without a LB"
draft: false
---

A few years back I worked on a project on AWS with some friends and we needed to load balance traffic. To save on the cost of an ALB, I decided on using round-robin DNS load balancing with Route53 and it worked for a while with long running instances, when we moved to an auto scaling setup things started to break as instances scaled up and down and required manual intervention to update DNS.

For most of us, the quick solution to this problem is to stick an ALB in front, but I decided to extend my DNS solution even further.

My solution was to run a Python script in AWS Lambda which updates the DNS in Route53 when an instance state changes in the autoscaling group. (Similar to dynamic DNS services). It is really easy to get the public IPv4 address of the instances from the auto scaling groups. Getting the IPv6 address turned out to be a bit of work, but it was easy to do if there is only one IPv6 address per instance. Also a thing to note is to keep the TTL lower to limit the chances of clients hitting an expired IP address.

```python
import boto3

def lambda_handler(event, context):

  ec2 = boto3.client('ec2')
  asg = boto3.client('autoscaling')
  r53 = boto3.client('route53')

  response = asg.describe_auto_scaling_groups(
      AutoScalingGroupNames=[
          'asg-name',
      ],
      MaxRecords=10
  )

  insids = []

  for asg in response['AutoScalingGroups']:
    for ins in asg['Instances']:
      insids.append(ins['InstanceId'])

  print(insids)

  response = ec2.describe_instances(
      InstanceIds=insids
  )

  ipv4 = []
  ipv6 = []

  for res in response['Reservations']:
    for ins in res['Instances']:
      ipv4.append({'Value': ins['PublicIpAddress'] })
      for net in ins['NetworkInterfaces']:
        for v6 in net['Ipv6Addresses']:
          ipv6.append({'Value': v6['Ipv6Address'] })

  print(ipv4)
  print(ipv6)

  domain = "example.com"

  response = r53.change_resource_record_sets(
      HostedZoneId='ZZZZZZZZZZZ',
      ChangeBatch={
          'Comment': 'auto dns update for asg',
          'Changes': [
              {
                  'Action': 'UPSERT',
                  'ResourceRecordSet': {
                      'Name': domain,
                      'Type': 'A',
                      'TTL': 300,
                      'ResourceRecords': ipv4
                  }
              },
              {
                  'Action': 'UPSERT',
                  'ResourceRecordSet': {
                      'Name': domain,
                      'Type': 'AAAA',
                      'TTL': 300,
                      'ResourceRecords': ipv6
                  }
              },
          ]
      }
  )

  print(response)  
```

For triggering the Lambda, I used Cloudwatch events to monitor the instance's lifecycle actions. Below is the AWS SAM template for the Lambda function. 

```yml
AWSTemplateFormatVersion: '2010-09-09'
Transform: 'AWS::Serverless-2016-10-31'
Description: An AWS Serverless Specification template describing your function.
Resources:
  UpdateDNS:
    Type: 'AWS::Serverless::Function'
    Properties:
      Handler: index.lambda_handler
      Runtime: python3.8
      CodeUri: .
      Description: ''
      MemorySize: 128
      Timeout: 6
      Role: 'arn:aws:iam::11111111111:role/service-role/UpdateDNS-role'
      Events:
        CloudWatchEvent1:
          Type: CloudWatchEvent
          Properties:
            Pattern:
              detail-type:
                - EC2 Instance-launch Lifecycle Action
                - EC2 Instance-terminate Lifecycle Action
              source:
                - aws.autoscaling
```

In the end, the solution worked perfectly and it also kept the cost low.
