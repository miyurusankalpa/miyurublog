---
title: Pull Docker Images via IPv6
date: "2022-11-09T19:19Z"
description: "How to use IPv6 and pull docker images via IPv6"
draft: false
---

As IPv6 only servers are becoming the norm, lots of users run into the problem of pulling docker images from docker hub.

The default endpoint does not have IPv6 enabled, but they have another endpoint `registry.ipv6.docker.com` which is dual stacked.

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

