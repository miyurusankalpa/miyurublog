---
title: IPv6 Keeps Breaking on Android with ZLT S12 Pro Router
date: "2025-11-26T13:07Z"
description: "ZLT S12 Pro IPv6 SLAAC timers are too low and unstable, causing Linux disconnects and Android bugs due to invalid lifetimes."
draft: false
---

I got a new router from a new ISP to check its IPv6 support. The router (ZLT S12 Pro) has an interesting IPv6 bug. Its IPv6 connection gets disconnected on Linux and is completely unusable on Android.

I checked the SLAAC settings using the **rdisc6** tool, and it seems the router sends the following values:

* Router lifetime: 4 minutes
* Valid time: 4 minutes
* Preferred time: 2 minutes

These are the maximum values, and they get lower over time because of the timers on successive solicitations.

```
Hop limit                 :           64 (      0x40)
Stateful address conf.    :           No
Stateful other conf.      :          Yes
Mobile home agent         :           No
Router preference         :       medium
Neighbor discovery proxy  :           No
Router lifetime           :          189 (0x000000bd) seconds
Reachable time            :  unspecified (0x00000000)
Retransmit time           :  unspecified (0x00000000)
 Source link-layer address: 98:A9:42:9C:68:21
 MTU                      :         1500 bytes (valid)
 Prefix                   : 2001:db8:a400:xxxx::/64
  On-link                 :          Yes
  Autonomous address conf.:          Yes
  Valid time              :          191 (0x000000bf) seconds
  Pref. time              :           71 (0x00000047) seconds
 Recursive DNS server     : 2001:db8:a400:xxxx:xxxx:xxxx:xxxx:xxxx
  DNS server lifetime     :          189 (0x000000bd) seconds
 from fe80::9aa9:42ff:fe9c:6821
```

There are multiple problems here.

1. These values are too low and should not be dynamic on a end users router.
2. Android discards lifetimes lower than 3 minutes. [IPv6 RA with AdvDefaultLifetime less than 180s not accepted by Android
](https://issuetracker.google.com/issues/428412059)

3. The router also uses the preferred time as a timer. All values reset when it reaches zero. At zero it sometimes it sends an RA packet with a **0 router lifetime**, which should not happen.


```
Hop limit                 :           64 (      0x40)
Stateful address conf.    :           No
Stateful other conf.      :          Yes
Mobile home agent         :           No
Router preference         :       medium
Neighbor discovery proxy  :           No
Router lifetime           :            0 (0x00000000) seconds
Reachable time            :  unspecified (0x00000000)
Retransmit time           :  unspecified (0x00000000)
 Source link-layer address: 98:A9:42:9C:68:21
 MTU                      :         1500 bytes (valid)
 Recursive DNS server     : fe80::9aa9:42ff:fe9c:6821
  DNS server lifetime     :         1800 (0x00000708) seconds
 from fe80::9aa9:42ff:fe9c:6821
```

This also triggers another Android bug. Which discards the IPv6 connection [Android loses IPv6 route after RA with lifetime 0 and refuses to restore it
](https://issuetracker.google.com/issues/429703129)

One of the way to fix it is the router should use static values and implement the guidelines in:
[draft-ietf-6man-slaac-renum-02 Section 4.1.1](https://datatracker.ietf.org/doc/html/draft-ietf-6man-slaac-renum-02#section-4.1.1)

I have reached to the ISP to fix this issue. Will update this post when they fix it.

> **Update:** The ISP did not fix the issue; however, I managed to solve it myself.
>
> 👉 **New Post:** https://blog.miyuru.lk/zlt-ipv6-fixes/

