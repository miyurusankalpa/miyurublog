---
title: Enabling IPv6 in Default VPC in AWS
date: "2023-11-25T16:04z"
description: "Enabling IPv6 in Default VPC in AWS using bash"
draft: false
---

IPv6 is the latest version of the Internet Protocol, which provides a larger address space, improved security, and enhanced performance for internet communications. However, AWS does not enable IPv6 by default in the default VPC, and some steps are required to enable it.

In this blog post, we will show you how to use a simple bash script to enable IPv6 support in the default VPC and subnets.

## Script
```bash
#!/bin/bash

# Get the default VPC ID
vpc_id=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text)

# Associate an Amazon-provided IPv6 CIDR block with the default VPC
aws ec2 associate-vpc-cidr-block \
  --vpc-id $vpc_id \
  --amazon-provided-ipv6-cidr-block

# Retrieve the assigned IPv6 CIDR block for the VPC
vpc_ipv6_cidr=$(aws ec2 describe-vpcs \
  --vpc-ids $vpc_id \
  --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' \
  --output text)

# Get all subnets in the VPC (returns array of [SubnetId, AvailabilityZone])
subnets=$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values=$vpc_id \
  --query 'Subnets[*].[SubnetId,AvailabilityZone]' \
  --output json)

# Count total subnets
subnet_count=$(echo $subnets | jq length)

# Loop subnets
for i in $(seq 0 $((subnet_count - 1))); do

  # Extract subnet ID and availability zone for current index
  subnet_id=$(echo $subnets | jq -r .[$i][0])
  subnet_az=$(echo $subnets | jq -r .[$i][1])

  # Assign a /64 IPv6 CIDR to the subnet based on its AZ suffix (e.g. "1a" → "1a::/64")
  aws ec2 associate-subnet-cidr-block \
    --subnet-id $subnet_id \
    --ipv6-cidr-block ${vpc_ipv6_cidr::-7}${subnet_az: -2}::/64

  sleep 1

  # Enable automatic IPv6 address assignment for instances launched in this subnet
  aws ec2 modify-subnet-attribute \
    --subnet-id $subnet_id \
    --assign-ipv6-address-on-creation

done

# Get the main route table for the VPC
route_table_id=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$vpc_id \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

# Get the Internet Gateway attached to the VPC
gateway_id=$(aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values=$vpc_id \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text)

# Add a default IPv6 route (::/0) pointing to the Internet Gateway
aws ec2 create-route \
  --route-table-id $route_table_id \
  --destination-ipv6-cidr-block ::/0 \
  --gateway-id $gateway_id
```

## Explanation

Here /56 for VPC and /64 for subnets are used. For subnets, last 2 letters of the Availability Zone are used. For example the subnet in `eu-central-1c` would get ip `2001:db8:ffff:ff1c::/64`

The script starts by getting the ID of the default VPC. Then it assigns an IPv6 CIDR block to the default VPC from the amazons IPv6 pool and get the newly assigned IPv6 CIDR.

Then it gets the subnets in the default VPC and loops through them and specify the custom IPv6 CIDR sub-block to each subnet and enable `assign-ipv6-address-on-creation` in each subnet.

Then it gets the ID of the route table and internet gateway of the default subnet and then create a default IPv6 route in the route table of the default subnet.

## Usage

Open a cloudshell in your aws account in the region you want to enable IPv6 for the default VPC.

Save the script to a file (e.g., `nano aws_ipv6_vpc.sh`).

Make it executable: `chmod +x aws_ipv6_vpc.sh`.

Run the script: `./aws_ipv6_vpc.sh`.

Check your AWS console to verify that the subnets have IPv6 address.

<hr>

Now your EC2 instances lauched in the default VPC will have IPv6 addresses by default. Make sure the configure the security groups to allow IPv6 traffic as well. 
You can also test the connectivity to other IPv6-enabled resources on the internet! 😊
