---
title: Enabling IPv6 in Default VPC in AWS
date: "2023-11-25T16:04z"
updated: "2026-05-19T12:57z"
description: "Enabling IPv6 in Default VPC in AWS using bash"
draft: false
---

IPv6 is the latest version of the Internet Protocol, which provides a larger address space, improved security, and enhanced performance for internet communications. However, AWS does not enable IPv6 by default in the default VPC, and some steps are required to enable it.

In this blog post, we will show you how to enable IPv6 support in the default VPC and subnets using a one-liner you can paste directly into AWS CloudShell.

## How it works

The script assigns an Amazon-provided IPv6 CIDR block to your default VPC, then creates a `/64` subnet in each Availability Zone. It enables automatic IPv6 address assignment on each subnet and adds a default `::/0` route pointing to the Internet Gateway.

> ℹ️ The one-liner below only enables IPv6 in the region of the CloudShell you run it in. To target a specific region or all regions, use the [multi-region script](#script-file) below.

### IPv6 addressing scheme

AWS assigns a `/56` block to the VPC. The script carves out a `/64` for each subnet using the last two characters of the Availability Zone:

```
VPC:  2001:db8:ffff:ff00::/56
       └── /64 subnets
            ├─ us-east-1a  →  2001:db8:ffff:ff1a::/64
            ├─ us-east-1b  →  2001:db8:ffff:ff1b::/64
            ├─ us-east-1c  →  2001:db8:ffff:ff1c::/64
            ├─ us-east-1d  →  2001:db8:ffff:ff1d::/64
            ├─ us-east-1e  →  2001:db8:ffff:ff1e::/64
            └─ us-east-1f  →  2001:db8:ffff:ff1f::/64

Instance launched in us-east-1a gets:
  IPv6 address = 2001:db8:ffff:ff1a::<assigned-id>
```

## Usage

Open a CloudShell in your AWS account in the region you want to enable IPv6 for the default VPC.

### One-line script

For a single-use, copy-and-run option, paste this one-liner directly into CloudShell. It enables IPv6 **only in the region your CloudShell runs in** — for all or specific regions, use the [multi-region script](#script-file) instead.

```bash
region=$(aws configure get region); echo "Enabling IPv6 in default VPC for region: $region"; vpc_id=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text); echo "Default VPC: $vpc_id"; vpc_ipv6_cidr=$(aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' --output text); if [ "$vpc_ipv6_cidr" = "None" ]; then echo "Associating IPv6 CIDR..."; aws ec2 associate-vpc-cidr-block --vpc-id $vpc_id --amazon-provided-ipv6-cidr-block >/dev/null; sleep 5; vpc_ipv6_cidr=$(aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' --output text); else echo "IPv6 CIDR already exists: $vpc_ipv6_cidr"; fi; echo "VPC IPv6 CIDR: $vpc_ipv6_cidr"; subnets=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id --query 'Subnets[*].[SubnetId,AvailabilityZone]' --output json); for i in $(seq 0 $(($(echo $subnets|jq length)-1))); do subnet_id=$(echo $subnets|jq -r .[$i][0]); subnet_az=$(echo $subnets|jq -r .[$i][1]); existing=$(aws ec2 describe-subnets --subnet-ids $subnet_id --query 'Subnets[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' --output text); if [ "$existing" = "None" ]; then aws ec2 associate-subnet-cidr-block --subnet-id $subnet_id --ipv6-cidr-block ${vpc_ipv6_cidr::-7}${subnet_az: -2}::/64 >/dev/null; sleep 1; echo "  Subnet $subnet_id ($subnet_az) -> IPv6 enabled"; else echo "  Subnet $subnet_id ($subnet_az) already has IPv6 ($existing)"; fi; aws ec2 modify-subnet-attribute --subnet-id $subnet_id --assign-ipv6-address-on-creation >/dev/null; done; route_table_id=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id Name=association.main,Values=true --query 'RouteTables[0].RouteTableId' --output text); gateway_id=$(aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query 'InternetGateways[0].InternetGatewayId' --output text); route_exists=$(aws ec2 describe-route-tables --route-table-ids $route_table_id --query "RouteTables[0].Routes[?DestinationIpv6CidrBlock == '::/0'].DestinationIpv6CidrBlock" --output text); if [ -n "$route_exists" ]; then echo "Default IPv6 route (::/0) already exists"; else aws ec2 create-route --route-table-id $route_table_id --destination-ipv6-cidr-block ::/0 --gateway-id $gateway_id >/dev/null && echo "Added default IPv6 route (::/0)"; fi; echo "IPv6 enabled in default VPC ($vpc_id) of $region. Instances will now get IPv6 addresses."
```

### Script file

You can also download and run the multi-region script directly:

```bash
curl -sL https://blog.miyuru.lk/aws_ipv6_vpc_multi.sh | bash
```

Or with a specific region:

```bash
curl -sL https://blog.miyuru.lk/aws_ipv6_vpc_multi.sh | bash -s -- us-east-1
```

[Download `aws_ipv6_vpc_multi.sh`](https://blog.miyuru.lk/aws_ipv6_vpc_multi.sh)

<hr>

Now your EC2 instances launched in the default VPC will have IPv6 addresses by default. Make sure to configure the security groups to allow IPv6 traffic as well. 
You can also test the connectivity to other IPv6-enabled resources on the internet! 😊

While you're at it, extend the same default VPC with free, dual-stack [gateway endpoints for S3 and DynamoDB](/aws-default-vpc-gateway-endpoints/) and keep that traffic off the public internet for free.
