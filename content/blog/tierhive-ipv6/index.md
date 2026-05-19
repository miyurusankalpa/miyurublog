---
title: Enabling IPv6 Automatically on TierHive Debian 13
date: "2026-05-19T20:54Z"
description: "Enabling IPv6 Automatically on TierHive Debian 13"
draft: true
---

> ⚠️ This assumes you will only add 1 IPv6 per host. If you plan to add more, add them from a separate part of the IPv6 range manually.

[TierHive](https://tierhive.com/r/6E5F34BFDF4B) recently added IPv6 support due to popular demand. Unfortunately they did not enable it by default, which they did for legacy IP.

To automate IPv6 setup, we will use the last octet of the IPv4 address to generate the IPv6 address, as TierHive does not seem to have a metadata endpoint.

eg: `10.4.243.2` will become `2001:db8:ffff:ffff::2`

You can follow the first part of the [TierHive IPv6 guide](https://tierhive.com/blog/technical_articles/configuring-ipv6) to create IPv6, and use the script below for last part.

```bash
TH_IPV6_SUBNET="2001:db8:ffff:ffff::/64"   #get subnet from control panel

# Get IPv4 from ens3
TH_IP_ADDR=$(ip -4 -o addr show dev ens3 | awk '{print $4}' | cut -d/ -f1)

# Extract last octet (10.4.243.2 -> 2)
LAST_OCTET=$(echo "$TH_IP_ADDR" | awk -F. '{print $4}')

# Strip /64 suffix to get the prefix (2001:db8:ffff:ffff::/64 -> 2001:db8:ffff:ffff::)
TH_IPV6_PREFIX="${TH_IPV6_SUBNET%/*}"

# Build IPv6 + gateway
TH_IPV6="${TH_IPV6_PREFIX}${LAST_OCTET}"
TH_GATEWAY="${TH_IPV6_PREFIX}1"

cat << EOF > /etc/netplan/51-ipv6.yaml
network:
  version: 2
  ethernets:
    ens3:
      addresses:
        - "$TH_IPV6/64"
      nameservers:
        addresses:
          - 2606:4700:4700::1111
          - 2001:4860:4860::8888
      gateway6: "$TH_GATEWAY"
EOF

netplan apply
```

To test IPv6 support:

```
ping google.com
```
