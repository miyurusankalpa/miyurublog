---
title: Adding IPv6 Support to S3 in AWS SDK
date: "2019-10-10T21:01z"
description: "Adding IPv6 Support to S3 in AWS SDK"
draft: false
---

In this post I am going to show how to enable IPv6 (dual stack) support for Amazon S3 in AWS CLI, AWS PHP SDK, JavaScript SDK, Python SDK (boto3), and Java SDK.

To enable IPv6 in CLI, enter the following command:

```bash
aws configure set default.s3.use_dualstack_endpoint true
```

This will enable S3 dual stack endpoints in the CLI.

To enable IPv6 in PHP, add the dualstack endpoint option to the array:

```php
// Enable dualstack endpoint
$s3 = new Aws\S3\S3Client([
  'version' => '2006-03-01',
  'region' => 'eu-west-1',
  'use_dual_stack_endpoint' => true
]);
```

To enable IPv6 in JavaScript, add the dualstack option to the configuration:

```js
// Enable dualstack endpoint
var bucket = new AWS.S3({
  useDualstack: true,
});
```

To enable IPv6 in Python (boto3), set the `use_dualstack_endpoint` parameter when creating the client:

```python
import boto3

s3 = boto3.client('s3', region_name='eu-west-1', use_dualstack_endpoint=True)
```

To enable IPv6 in Java SDK v2, use the `dualstackEnabled` option in the S3 client builder:

```java
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;

S3Configuration s3Config = S3Configuration.builder()
    .dualstackEnabled(true)
    .build();

S3Client s3 = S3Client.builder()
    .region(Region.EU_WEST_1)
    .serviceConfiguration(s3Config)
    .build();
```
