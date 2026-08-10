---
title: "Enabling Free S3 and DynamoDB Gateway Endpoints in Default VPC in AWS"
date: "2026-08-10T12:00z"
updated: "2026-08-10T12:00z"
description: "Creating free S3 and DynamoDB Gateway Endpoints in Default VPC in AWS using bash"
draft: false
---

Amazon S3 and DynamoDB are probably the AWS services you use the most, but traffic to them from your VPC normally leaves through the internet gateway (or a NAT gateway) and accrues data transfer charges. By creating a **VPC Gateway Endpoint** for each service, that traffic is routed over AWS's internal network instead — and unlike interface endpoints, gateway endpoints are **completely free of charge**.

Gateway endpoints support only two services — S3 and DynamoDB — and since late 2025 they also support IPv6. That makes this post the perfect companion to [Enabling IPv6 in Default VPC in AWS](/aws-default-vpc-ipv6/): once your default VPC has IPv6, these free gateway endpoints let your S3 and DynamoDB traffic flow over IPv6 *and* stay inside the AWS network, free of data transfer charges.

In this blog post, we will show you how to create S3 and DynamoDB gateway endpoints for the default VPC using a one-liner you can paste directly into AWS CloudShell.

## How it works

A gateway endpoint is not a resource inside your subnet like an interface endpoint — it is a **route target**. When you create one, you pick the VPC and its route tables; AWS then automatically adds a route for each route table you select. The route destination is an AWS-managed prefix list (`pl-…`) that tracks the current IP ranges of the service in that region, and the target is the endpoint.

You cannot modify or delete these routes while the endpoint is associated — they are managed entirely by AWS. Requests destined for S3 or DynamoDB match the endpoint route and are forwarded over the AWS backbone rather than the public internet, and because the prefix list is updated by AWS, you never have to touch your route tables again.

> ℹ️ Gateway endpoints are free — there are no hourly charges and no data transfer charges for traffic to S3 or DynamoDB through the endpoint. Interface endpoints, NAT gateways and AWS transit costs, so this is the cheapest way to reach S3 and DynamoDB from a VPC.

### IPv6 addressing

Since November 2025, gateway endpoints can be created as IPv4, IPv6, or dual-stack. When your default VPC already has an IPv6 CIDR block (from the [IPv6 in the default VPC post](/aws-default-vpc-ipv6/)), the script creates the endpoints as **dualstack** and AWS adds both the IPv4 and IPv6 prefix-list routes to your route table:

```
Route table in default VPC:
  Destination               Target
  10.0.0.0/16               local
  pl-… (S3, IPv4)           vpce-…   → S3 over IPv4
  ::/0 (S3, IPv6)           vpce-…   → S3 over IPv6
  pl-… (DynamoDB, IPv4)     vpce-…   → DynamoDB over IPv4
  ::/0 (DynamoDB, IPv6)     vpce-…   → DynamoDB over IPv6
```

If the service in your region does not yet accept dual-stack, the script falls back to IPv4 automatically.

## Usage

Open a CloudShell in your AWS account in the region you want to create the endpoints for the default VPC.

### One-line script

For a single-use, copy-and-run option, paste this one-liner directly into CloudShell. It creates the endpoints **only in the region your CloudShell runs in** — for all or specific regions, use the [multi-region script](#script-file) instead.

```bash
region=$(aws configure get region); vpc_id=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text) && rt=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id Name=association.main,Values=true --query 'RouteTables[0].RouteTableId' --output text) && it=$(aws ec2 describe-vpcs --vpc-ids $vpc_id --query 'Vpcs[0].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' --output text | grep -q ':' && echo dualstack || echo ipv4) && echo "Region: $region | VPC: $vpc_id | Route table: $rt | $it" && for svc in s3 dynamodb; do aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.$region.$svc --vpc-endpoint-type Gateway --route-table-ids $rt --ip-address-type $it --query 'VpcEndpoint.VpcEndpointId' --output text 2>/dev/null || aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.$region.$svc --vpc-endpoint-type Gateway --route-table-ids $rt --query 'VpcEndpoint.VpcEndpointId' --output text; done
```

### Script file

You can also download and run the multi-region script directly:

```bash
curl -sL https://blog.miyuru.lk/aws_vpc_gateway_endpoints.sh | bash
```

Or with a specific region:

```bash
curl -sL https://blog.miyuru.lk/aws_vpc_gateway_endpoints.sh | bash -s -- us-east-1
```

[Download `aws_vpc_gateway_endpoints.sh`](https://blog.miyuru.lk/aws_vpc_gateway_endpoints.sh)

<hr>

Now your instances in the default VPC will reach S3 and DynamoDB privately, for free — over both IPv4 and IPv6. The endpoints use the default full-access policy; you can narrow it anytime from the console by attaching a custom endpoint policy.

Also, if you haven't already, check out [Enabling IPv6 in Default VPC in AWS](/aws-default-vpc-ipv6/) so these dual-stack endpoints have an IPv6 path to use. 😊