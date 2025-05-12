---
title: Adding IPv6 Support to SES in AWS SDK
date: "2025-05-12T14:53Z"
description: "Adding IPv6 Support to SES in AWS SDK"
draft: false
---

In this post I am going to show how to enable IPv6 (dual stack) support for Amazon SES in AWS PHP SDK, JavaScript SDK and Python SDK (boto3).

> ⚠️ Note: Despite the blog post on May 5, 2025, the AWS SDK does not seem to support the dualstack endpoint at the posting of the blog post. This blog post uses a custom function to get and set the dualstack endpoint. https://aws.amazon.com/about-aws/whats-new/2025/05/amazon-ses-ipv6-calling-ses-outbound-endpoints/

To enable IPv6 in PHP, add the `use_dualstack_endpoint` option to the configuration:

```php
/**
 * Return the SES API endpoint domain for a given region.
 *
 * @param string $region AWS region (e.g. "eu-central-1")
 * @return string
 */
function getSesApiEndpoint(string $region): string {
    return "email.$region.api.aws"; 
}

// Usage:
$region = 'eu-central-1';
$SesClient = new SesClient([
    'version'                  => '2010-12-01',
    'region'                   => $region,
    'use_dualstack_endpoint'   => true,
    'endpoint'                 => 'https://' . getSesApiEndpoint($region), //tmp fix till the endpoints are added to SDK
]);
```

To enable IPv6 in JavaScript, add the `useDualstackEndpoint` option to the configuration:

```js
/**
 * Return the SES API endpoint URL for a given region.
 * @param {string} region AWS region, e.g. "eu-central-1"
 * @returns {string}
 */
function getSesApiEndpoint(region) {
  return `https://email.${region}.api.aws`;
}

// Usage:
const region = 'eu-central-1';
const client = new SESClient({
  region,
  useDualstackEndpoint: true,
  endpoint: getSesApiEndpoint(region) //tmp fix till the endpoints are added to SDK
});
```

To enable IPv6 in Python (boto3), set the `use_dualstack_endpoint` parameter when creating the client:

```python
def get_ses_api_endpoint(region: str) -> str:
    """
    Return the SES API endpoint URL for a given region.
    """
    return f"https://email.{region}.api.aws"

# Usage:
region = 'eu-central-1'
ses = boto3.client(
    'ses',
    region_name=region,
    use_dualstack_endpoint=True,
    endpoint_url=get_ses_api_endpoint(region) #tmp fix till the endpoints are added to SDK
)
```

