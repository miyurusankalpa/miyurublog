---
title: Using IPv6 to serve github pages on custom domains 
date: "2019-04-23T23:00"
description: "Using IPv6 to serve github pages on custom domains "
draft: false
---

Even though currently github pages does not support IPv6, their CDN fastly does.

> ⚠️Please do this only If you know what you are doing! This IP can change at any moment.

To add IPv6 support, add a AAAA reccord in your DNS with the following IPv6 address.

    2a04:4e42::133

This IP is the anycasted IPv6 address of Fasly CDN which serves Github Pages. **It is recommended to use this with Cloudflare Proxy as HTTPS does not work with custom domains with this IP**.

In fact this blog is powered with IPv6 Github Pages.

![Cloudflare IPv6 GitHub Pages](cf-blog-github.png)