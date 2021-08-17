---
title: Using IPv6 to serve github pages on custom domains
date: "2021-08-14T23:00"
description: "Using IPv6 to serve github pages on custom domains"
draft: false
---

New IPv4 and IPv6 address for Github Pages are as below. **SSL are working on these IPv6 addresses.**

```
185.199.108.153  - >  2606:50c0:8000::153
185.199.109.153  - >  2606:50c0:8001::153
185.199.110.153  - >  2606:50c0:8002::153
185.199.111.153  - >  2606:50c0:8003::153
```
=============================================

*2019-04-23 - Original Post*

Even though currently github pages does not support IPv6, their CDN fastly does.

> ⚠️Please do this only If you know what you are doing! This IP can change at any moment.

To add IPv6 support, add a AAAA reccord in your DNS with the following IPv6 address.

    2a04:4e42::133

This IP is the anycasted IPv6 address of Fasly CDN which serves Github Pages. **It is recommended to use this with Cloudflare Proxy as HTTPS does not work with custom domains with this IP**.

In fact this blog is powered with IPv6 Github Pages.

![Cloudflare IPv6 GitHub Pages](cf-blog-github.png)
