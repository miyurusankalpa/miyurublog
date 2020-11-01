---
title: Copying AWS Tags using CLI
date: "2020-04-11T17:43Z"
description: "Copying AWS Tags using CLI"
draft: false
---

When the AWS account have large number of resources mainlining them tags are used. Normally these tagged are added using the cloud formation templates but some times you need to manually copy them.  

The following CLI command queries the tags and saves them to a json file.

    aws ec2 describe-tags --filters Name=resource-id,Values={{ OLD_RESOURCE_ID }} --query 'Tags[].{Key:Key,Value:Value}' --profile {{ AWS_PROFILE }}> tags.json
    

  
The following CLI command takes the exported tags using the json files and adds them to the new resource.

    aws ec2 create-tags --resources {{ NEW_RESOURCE_ID }} --tags file://tags.json--profile  {{ AWS_PROFILE }}
    

Hope this helps someone.