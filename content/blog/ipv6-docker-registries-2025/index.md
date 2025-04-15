---
title: IPv6 Support in Public Docker Registries
date: "2025-04-15T22:27Z"
description: "Finding out IPv6 Support in Public Docker Registries in 2025"
draft: false
---

[Back in 2021, I checked for IPv6 support in public registries in the Docker Hub IPv6 support thread](https://github.com/docker/roadmap/issues/89#issuecomment-772644009). Since Docker Hub now has IPv6 support, I wanted to see how other registries have fared.

> **⚠️ Note:** The registry domains referenced here might change in the future. For a full domain list and upto date infomation on IPv6 support, please refer to the [v6monitor list](https://v6monitor.com/list/view/cf170dba3/).

## Results

Below are the tests I conducted using various registry domains. For each registry, I recorded the Docker endpoint result and used tcpdump to get the auth/blob domain. The registry endpoint is in **bold**.

### Docker Hub: Fully supports IPv6
- **docker.io (registry-1.docker.io)**: **PASS**
- docker-images-prod.6aa30f8b08e16409b46e0173d6de2f56.r2.cloudflarestorage.com: PASS
- production.cloudflare.docker.com: PASS

### Red Hat Quay: Fully supports IPv6
- **quay.io**: **PASS**
- cdn01.quay.io: PASS
- cdn02.quay.io: PASS

### GitHub Container Registry: Only blob endpoint supports IPv6
- **ghcr.io**: **FAIL**
- pkg-containers.githubusercontent.com: PASS

### GitLab Container Registry: No IPv6 support
- **registry.gitlab.com**: **FAIL**
- cdn.registry.gitlab-static.net: FAIL

### AWS Public ECR: Only blob domain supports IPv6
- **public.ecr.aws**: **FAIL**
- d5l0dvt14r5h8.cloudfront.net: PASS

### Scaleway Docker Registry: Only blob domain supports IPv6
- **rg.nl-ams.scw.cloud**: **FAIL**
- api.scaleway.com: FAIL
- s3.nl-ams.scw.cloud: PASS

### Google Artifact Registry: Fully supports IPv6
- **gcr.io**: **PASS**

### Alibaba Cloud Registry: Only auth domain supports IPv6
- **registry.cn-hangzhou.aliyuncs.com**: **FAIL**
- dockerauth.cn-hangzhou.aliyuncs.com: PASS
- aliregistry.oss-cn-hangzhou.aliyuncs.com: FAIL

### Microsoft Container Registry: Fully supports IPv6
- **mcr.microsoft.com**: **PASS**

### Kubernetes Registry: Supports IPv6
- **registry.k8s.io**: **PASS**
- prod-registry-k8s-io-ap-south-1.s3.dualstack.ap-south-1.amazonaws.com: SPASS

> ⚠️ Note: Blob endpoint seems to use different provider S3 buckets based on regions. For my region, it has IPv6 support.

## Redirect Domains

- **registry.access.redhat.com**: Domain supports IPv6. Then it redirects to Red Hat Quay.
- **lscr.io**: Domain does not support IPv6. Then it redirects to GitHub Container Registry.

## Summary and Recommendations

Based on the tests conducted, here's a summary table of registry IPv6 support and recommendations for environments where IPv6 is crucial:

| Registry | Docker Endpoint | Blob Endpoint | Overall IPv6 Support | Recommendation |
|----------|----------------|---------------|---------------------|----------------|
| Docker Hub (docker.io) | ✅ | ✅ | Full | Highly Recommended |
| Red Hat Quay (quay.io) | ✅ | ✅ | Full | Highly Recommended |
| Google Artifact Registry (gcr.io) | ✅ | ✅ | Full | Highly Recommended |
| Microsoft Container Registry (mcr.microsoft.com) | ✅ | ✅ | Full | Recommended |
| Kubernetes Registry (registry.k8s.io) | ✅ | ✅ | Full | Recommended |
| GitHub Container Registry (ghcr.io) | ❌ | ✅ | Partial | Recommend to use with NAT64 |
| AWS Public ECR (public.ecr.aws) | ❌ | ✅ | Partial | Recommend to use with NAT64 |
| Scaleway Docker Registry (rg.nl-ams.scw.cloud) | ❌ | ✅ | Partial | Recommend to use with NAT64 |
| Alibaba Cloud Registry (registry.cn-hangzhou.aliyuncs.com) | ❌ | ❌ | Partial | Not recommended |
| GitLab Container Registry (registry.gitlab.com) | ❌ | ❌ | None | Not recommended |


For IPv6-only or IPv6-first environments, I recommend using registries with full IPv6 support such as Docker Hub, Red Hat Quay and Google Artifact Registry.

I recommend using NAT64 because the blob endpoint handles the most bandwidth-intensive downloads, which puts the most burden on the NAT64 server. You can use one from https://nat64.xyz/, but in my testing, most of them seemed to be rate-limited at the Docker endpoint due to high usage.

