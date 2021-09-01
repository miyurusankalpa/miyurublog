---
title: Adding IPv6 Support to S3 in AWS SDK
date: "2019-10-10T21:01z"
description: "Adding IPv6 Support to S3 in AWS SDK"
draft: false
---

In this post I am going to show how to enable IPv6(dual stack) support Amazon S3 in AWS CLI and on AWS PHP SDK.

To enable IPv6 in CLI, enter the following command:

```bash
aws configure set default.s3.use_dualstack_endpoint true
```

This will enable S3 dual stack endpoints in the CLI.

To enable IPv6 in PHP, add use dualstack endpoint option to the array:

```{diff}
 // Enable dualstack endpoint
 $s3 = new Aws\S3\S3Client([
   'version' => '2006-03-01',
   'region' => 'eu-west-1',
+    'use_dual_stack_endpoint' => true
 ]);
```

To enable IPv6 in Javascript, add use dualstack option to the array:

```{diff}
 // Enable dualstack endpoint
var bucket = new AWS.S3({
+  useDualstack : true,
})
```