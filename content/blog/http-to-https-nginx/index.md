---
title: HTTP to HTTPS Nginx
date: "2019-04-06T21:50Z"
description: "HTTP to HTTPS Nginx"
draft: false
---

There are 2 methods to redirect to https in Nginx

1st method is to create a separate server block for port 80 and redirect all to https.

    server {
      listen 80; //ipv4
      listen [::]:80; //ipv6
      server_name example.com;
      return 301 https://$host$request_uri;
    }

2nd method is to add a if statement and redirect only if the check is true.

    if ($scheme = http) {
      return 301 https://$host$request_uri;
    }

if you use cloudflare you can use the following statement to redirect traffic to https

    if ($http_cf_visitor ~ '{"scheme":"http"}') {
      return 301 https://$host$request_uri;
    }
