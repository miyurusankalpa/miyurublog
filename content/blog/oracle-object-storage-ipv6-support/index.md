---
title: Adding IPv6 Support to Oracle Object Storage
date: "2026-03-27T21:01z"
description: "Adding IPv6 Support to Oracle Object Storage"
draft: false
---

## Oracle Object Storage (S3 Compatible + IPv6)

Oracle Object Storage provides S3-compatible APIs and now supports newer endpoint formats and dual-stack (IPv4/IPv6) access.

### 🔄 Endpoint Conversion Table

### Native API

| Type | Value |
|------|-------|
| Old | `objectstorage.$region.oraclecloud.com` |
| New | `objectstorage.$region.oci.customer-oci.com` |
| IPv6 (.ds) | `objectstorage.$region.ds.oci.customer-oci.com` |

---

### Native API (Namespace)

| Type | Value |
|------|-------|
| New | `$namespace.objectstorage.$region.oci.customer-oci.com` |
| IPv6 (.ds) | `$namespace.objectstorage.$region.ds.oci.customer-oci.com` |

---

### S3 Compatible API

| Type | Value |
|------|-------|
| Old | `$namespace.compat.objectstorage.$region.oraclecloud.com` |
| New | `$namespace.compat.objectstorage.$region.oci.customer-oci.com` |
| IPv6 (.ds) | `$namespace.compat.objectstorage.$region.ds.oci.customer-oci.com` |

---

### Swift API

| Type | Value |
|------|-------|
| Old | `swiftobjectstorage.$region.oraclecloud.com` |
| New | `swiftobjectstorage.$region.oci.customer-oci.com` |
| IPv6 (.ds) | `swiftobjectstorage.$region.ds.oci.customer-oci.com` |

---

## 🌐 IPv6 Support (Oracle)

Oracle Cloud Infrastructure supports **dual-stack IPv4 + IPv6 networking**, meaning services can be accessed over both protocols.

Just like AWS S3, **dual-stack endpoints resolve to IPv4 or IPv6 automatically** depending on the client.

For Oracle Object Storage, use `.ds` endpoints to ensure IPv6 support.

---

## 🧰 Oracle S3-Compatible SDK Examples

### CLI (AWS CLI compatible)

```bash
aws configure set default.s3.endpoint_url https://$namespace.compat.objectstorage.$region.ds.oci.customer-oci.com
````

---

### PHP

```php
$s3 = new Aws\S3\S3Client([
  'version' => 'latest',
  'region' => 'us-ashburn-1',
  'endpoint' => 'https://$namespace.compat.objectstorage.us-ashburn-1.ds.oci.customer-oci.com',
  'use_path_style_endpoint' => true
]);
```

---

### JavaScript

```js
var bucket = new AWS.S3({
  endpoint: "https://$namespace.compat.objectstorage.us-ashburn-1.ds.oci.customer-oci.com",
  s3ForcePathStyle: true,
});
```

---

### Python (boto3)

```python
import boto3

s3 = boto3.client(
    's3',
    region_name='us-ashburn-1',
    endpoint_url='https://$namespace.compat.objectstorage.us-ashburn-1.ds.oci.customer-oci.com'
)
```

---

### Java SDK v2

```java
S3Client s3 = S3Client.builder()
    .region(Region.US_ASHBURN_1)
    .endpointOverride(URI.create("https://$namespace.compat.objectstorage.us-ashburn-1.ds.oci.customer-oci.com"))
    .build();
```

