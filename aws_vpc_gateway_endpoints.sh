#!/bin/bash

# Create free VPC Gateway Endpoints for Amazon S3 and DynamoDB in the default VPC.
# Gateway endpoints have no hourly or data transfer charges - unlike interface
# endpoints. When the default VPC already has an IPv6 CIDR block (e.g. from
# aws_ipv6_vpc_multi.sh), the endpoints are created as dualstack so S3 and
# DynamoDB traffic can also flow over IPv6 for free.
# Usage:
#   ./aws_vpc_gateway_endpoints.sh             # create in every enabled region
#   ./aws_vpc_gateway_endpoints.sh us-east-1   # create only in the given region

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

  # Get the main route table (all default-VPC subnets use it)
  route_table_id=$(aws ec2 describe-route-tables \
    --region $region \
    --filters Name=vpc-id,Values=$vpc_id \
              Name=association.main,Values=true \
    --query 'RouteTables[0].RouteTableId' \
    --output text)

  # Check whether the VPC has an IPv6 CIDR block
  vpc_ipv6_cidr=$(aws ec2 describe-vpcs \
    --region $region \
    --vpc-ids $vpc_id \
    --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' \
    --output text)

  if [ -n "$vpc_ipv6_cidr" ] && [ "$vpc_ipv6_cidr" != "None" ]; then
    ip_type="dualstack"
  else
    ip_type="ipv4"
  fi

  echo "VPC $vpc_id ($ip_type) -> route table $route_table_id"

  create_endpoint() {
    local service_name=$1

    # Skip if a gateway endpoint for this service already exists
    existing=$(aws ec2 describe-vpc-endpoints \
      --region $region \
      --filters Name=vpc-id,Values=$vpc_id \
                Name=service-name,Values=$service_name \
                Name=vpc-endpoint-type,Values=Gateway \
      --query 'VpcEndpoints[0].VpcEndpointId' \
      --output text)

    if [ -n "$existing" ] && [ "$existing" != "None" ]; then
      echo "  $service_name: already exists ($existing), skipping"
      return
    fi

    # Prefer dualstack (IPv4 + IPv6); fall back to IPv4 if rejected
    endpoint_id=$(aws ec2 create-vpc-endpoint \
      --region $region \
      --vpc-id $vpc_id \
      --service-name $service_name \
      --vpc-endpoint-type Gateway \
      --route-table-ids $route_table_id \
      --ip-address-type $ip_type \
      --query 'VpcEndpoint.VpcEndpointId' \
      --output text 2>/dev/null)

    if [ $? -ne 0 ]; then
      endpoint_id=$(aws ec2 create-vpc-endpoint \
        --region $region \
        --vpc-id $vpc_id \
        --service-name $service_name \
        --vpc-endpoint-type Gateway \
        --route-table-ids $route_table_id \
        --query 'VpcEndpoint.VpcEndpointId' \
        --output text)
    fi

    echo "  $service_name -> $endpoint_id"
  }

  create_endpoint com.amazonaws.$region.s3
  create_endpoint com.amazonaws.$region.dynamodb

  # Show the endpoint routes added to the route table
  aws ec2 describe-route-tables \
    --region $region \
    --route-table-ids $route_table_id \
    --query 'RouteTables[0].Routes[?starts_with(GatewayId, `vpce-`)].[DestinationPrefixListId, DestinationIpv6CidrBlock, GatewayId]' \
    --output table

done