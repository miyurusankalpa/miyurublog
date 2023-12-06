---
title: Pull Docker Images via IPv6
date: "2022-11-09T19:19Z"
description: "How to use IPv6 and pull docker images via IPv6"
draft: false
---

As IPv6 only servers are becoming the norm, lots of users run into the problem of pulling docker images from docker hub.

> ⚠️ As of August 2023 docker hub supports IPv6 https://www.docker.com/blog/docker-hub-registry-ipv6-support-now-generally-available/ the following sentence have been updated to reflect that.

The default endpoint is dual stacked, but they have another endpoint `registry.ipv6.docker.com` which is IPv6 only.

So instead of using
`docker pull busybox`

You can prefix the IPv6 docker endpoint with library and pull the docker image.
`docker pull registry.ipv6.docker.com/library/busybox`


However, this is only suitable for one time use and advanced users will need to edit dockerfiles to add the new endpoint.

Instead of that, you can add the endpoint as a mirror to the config as solve this problem.

In Linux config is at `/etc/docker/daemon.json`

```
{
   "registry-mirrors": [
     "https://registry.ipv6.docker.com"
   ]
}
```

