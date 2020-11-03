---
title: Archive.is Cloudflare Fix
date: "2019-07-27T01:08Z"
description: "Archive.is Cloudflare Fix"
draft: false
---

It has been [reported](https://community.cloudflare.com/t/archive-is-error-1001/18227/10?u=miyurusankalpa) that archive.is blocks cloudflare DNS due to cloudflare not supporting EDNS.

While a quick fix might be to change the DNS, another way to fix it while keeping the DNS is to change the hosts file.

> ⚠️Please do this only If you know what you are doing! This IP can change at any moment.

> ⚠️This method will not works DNS over HTTPS.

Edit the hosts file and add the following entries and you will be able to access archive.is even while using cloudflare DNS.

```
2001:41d0:1:8720::1 archive.is
91.121.82.32 archive.is
```
