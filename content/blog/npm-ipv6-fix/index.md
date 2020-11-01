---
title: NPM IPv6 fix
date: "2019-07-15T00:41Z"
description: "NPM IPv6 fix"
draft: false
---

> [Error : getaddrinfo ENOTFOUND registry.npmjs.org registry.npmjs.org:443](https://stackoverflow.com/questions/39592908/error-getaddrinfo-enotfound-registry-npmjs-org-registry-npmjs-org443)

if you face the above error when trying to install NPM packages on a IPv6 only connection, add the following to the hosts file.

> ⚠️Please do this only If you know what you are doing! This IP can change at any moment.
```
2606:4700::6810:1123 registry.npmjs.org
```