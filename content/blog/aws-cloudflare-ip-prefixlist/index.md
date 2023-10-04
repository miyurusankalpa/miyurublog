---
title: Adding Cloudflare IP to AWS Prefix List
date: "2023-10-05T18:47z"
description: "Adding Cloudflare IP to AWS Prefix List using bash"
draft: false
---

If you’re managing an AWS environment and want to keep your security groups up-to-date with Cloudflare’s IPv6 addresses, this script can help. 
Cloudflare provides a list of their IPv6 addresses, and we’ll use this information to create an AWS managed prefix list that you can reference in your security group rules.

## Script
```bash
#!/bin/bash

curl -s https://www.cloudflare.com/ips-v6/ > /tmp/cloudflare_ipv6.txt

region=`aws ec2 describe-availability-zones --output text --query 'AvailabilityZones[0].[RegionName]'`

# Add each IPv6 address to AWS prefix list
while read -r ipv6; do
    entries+="Cidr=$ipv6,Description=Cloudflare_IPv6 "
done < /tmp/cloudflare_ipv6.txt

echo $entries

entries_count=`wc -l < /tmp/cloudflare_ipv6.txt`

date=$(date '+%Y-%m-%d %H:%M:%S')

aws ec2 create-managed-prefix-list --prefix-list-name "Cloudflare_IPv6_$date" --address-family IPv6 --max-entries $entries_count  --region $region --entries $entries 
```

## Explanation

The script starts by downloading the list of Cloudflare’s IPv6 addresses using curl. These addresses are stored in a file called `cloudflare_ipv6.txt` in the tmp directory.

Next, it determines the AWS region using the `aws ec2 describe-availability-zones` command.

The while loop reads each line from `/tmp/cloudflare_ipv6.txt` and constructs a string of entries in the format required for creating an AWS prefix list.

We calculate the number of entries in the file to set the `max-entries` parameter for the prefix list.

The current date and time are captured using `date`, which will be included in the prefix list name.

Finally, it uses `aws ec2 create-managed-prefix-list` to create the managed prefix list with a unique name based on the date and time.


## Usage

Open a cloudshell in your aws account.

Save the script to a file (e.g., `nano cloudflare_aws.sh`).

Make it executable: `chmod +x cloudflare_aws.sh`.

Run the script: `./cloudflare_aws.sh`.

Check your AWS console to verify that the new “Cloudflare_IPv6” prefix list with a timestamp has been created.

<hr>

Now you can reference this prefix list in your security group rules to allow traffic from Cloudflare’s IPv6 addresses.

Feel free to customize this script further to add IPv4 support or integrate it into your existing automation workflows! 😊

