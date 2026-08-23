#!/bin/bash

# Enable IPv6 in the default VPC across one or all regions.
# Usage:
#   ./aws_ipv6_vpc_multi.sh             # enable in every enabled region
#   ./aws_ipv6_vpc_multi.sh us-east-1   # enable only in the given region

if [ $# -gt 0 ]; then
  regions=$1
else
  regions=$(aws ec2 describe-regions \
    --query 'Regions[*].RegionName' \
    --output text)
fi

for region in $regions; do
  echo "=== $region ==="

  # Get the default VPC ID
  vpc_id=$(aws ec2 describe-vpcs \
    --region $region \
    --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' \
    --output text)

  # Reuse an existing IPv6 CIDR block if present, otherwise associate one
  vpc_ipv6_cidr=$(aws ec2 describe-vpcs \
    --region $region \
    --vpc-ids $vpc_id \
    --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' \
    --output text)

  if [ "$vpc_ipv6_cidr" = "None" ]; then
    echo "  Associating Amazon-provided IPv6 CIDR block..."

    # Associate an Amazon-provided IPv6 CIDR block with the default VPC
    aws ec2 associate-vpc-cidr-block \
      --region $region \
      --vpc-id $vpc_id \
      --amazon-provided-ipv6-cidr-block > /dev/null

    sleep 5

    # Retrieve the assigned IPv6 CIDR block for the VPC
    vpc_ipv6_cidr=$(aws ec2 describe-vpcs \
      --region $region \
      --vpc-ids $vpc_id \
      --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' \
      --output text)
  else
    echo "  IPv6 CIDR already exists ($vpc_ipv6_cidr), reusing"
  fi

  # Get all subnets in the VPC (returns array of [SubnetId, AvailabilityZone])
  subnets=$(aws ec2 describe-subnets \
    --region $region \
    --filters Name=vpc-id,Values=$vpc_id \
    --query 'Subnets[*].[SubnetId,AvailabilityZone]' \
    --output json)

  subnet_count=$(echo $subnets | jq length)

  for i in $(seq 0 $((subnet_count - 1))); do

    subnet_id=$(echo $subnets | jq -r .[$i][0])
    subnet_az=$(echo $subnets | jq -r .[$i][1])

    # Skip subnets that already have an IPv6 CIDR
    existing_cidr=$(aws ec2 describe-subnets \
      --region $region \
      --subnet-ids $subnet_id \
      --query 'Subnets[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' \
      --output text)

    if [ "$existing_cidr" = "None" ]; then
      # Assign a /64 IPv6 CIDR to the subnet based on its AZ suffix
      aws ec2 associate-subnet-cidr-block \
        --region $region \
        --subnet-id $subnet_id \
        --ipv6-cidr-block ${vpc_ipv6_cidr::-7}${subnet_az: -2}::/64 > /dev/null

      sleep 1
    else
      echo "  Subnet $subnet_id ($subnet_az): IPv6 already configured ($existing_cidr)"
    fi

    # Enable automatic IPv6 address assignment for instances launched in this subnet
    aws ec2 modify-subnet-attribute \
      --region $region \
      --subnet-id $subnet_id \
      --assign-ipv6-address-on-creation

  done

  # Get the main route table for the VPC
  route_table_id=$(aws ec2 describe-route-tables \
    --region $region \
    --filters Name=vpc-id,Values=$vpc_id \
              Name=association.main,Values=true \
    --query 'RouteTables[0].RouteTableId' \
    --output text)

  # Get the Internet Gateway attached to the VPC
  gateway_id=$(aws ec2 describe-internet-gateways \
    --region $region \
    --filters Name=attachment.vpc-id,Values=$vpc_id \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text)

  # Skip if the default IPv6 route already exists
  route_exists=$(aws ec2 describe-route-tables \
    --region $region \
    --route-table-ids $route_table_id \
    --query "RouteTables[0].Routes[?DestinationIpv6CidrBlock == '::/0'].DestinationIpv6CidrBlock" \
    --output text)

  if [ -z "$route_exists" ]; then
    echo "  Adding default IPv6 route (::/0) to Internet Gateway"

    # Add a default IPv6 route (::/0) pointing to the Internet Gateway
    aws ec2 create-route \
      --region $region \
      --route-table-id $route_table_id \
      --destination-ipv6-cidr-block ::/0 \
      --gateway-id $gateway_id > /dev/null
  else
    echo "  Default IPv6 route (::/0) already exists"
  fi

done
