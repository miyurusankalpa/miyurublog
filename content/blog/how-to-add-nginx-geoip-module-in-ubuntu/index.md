---
title: How to add nginx geoip module in ubuntu
date: "2019-04-06T21:32Z"
description: "How to add nginx geoip module in ubuntu"
draft: false
---

First add the nginx stable repo:
```bash
sudo add-apt-repository ppa:nginx/stable
```

Then run apt update:
```bash
sudo apt-get update
```
And get the nginx geoip module:
```bash
sudo apt-get install nginx-module-geoip
```

This will download and load the module to /usr/lib/nginx/modules

To load the nginx module, open nginx.conf:

```bash
sudo nano /etc/nginx/nginx.conf
```
add add below in the main context:

```
load_module "modules/ngx_http_geoip_module.so";
```

The module will be loaded, when you reload the configuration or restart nginx.

_To dynamically “unload” a module, comment out or remove its load_module directive and reload the nginx configuration.