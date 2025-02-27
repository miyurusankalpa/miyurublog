---
title: Speeding Up Your Network with Google BBR
date: "2025-02-28T19:27Z"
description: "Speeding Up Your Network with Google BBR which is a congestion control algorithm that can significantly improve network performance"
draft: false
---

# Speeding Up Your Network with Google BBR

Google's BBR (Bottleneck Bandwidth and Round-trip propagation time) is a congestion control algorithm that can significantly improve network performance. In this post, I'll guide you through enabling BBR on your Linux system to boost network speeds.

## What is BBR?

BBR is a TCP congestion control algorithm developed by Google that optimizes network throughput and reduces latency. Unlike traditional loss-based congestion control algorithms, BBR uses bandwidth and round-trip time measurements to build a model of the network, allowing for better utilization of available bandwidth.

## Prerequisites

Before we begin, ensure you have:
- A Linux system with root access
- A kernel version 4.9 or newer

## Step 1: Check if BBR is available in your kernel

First, let's check if BBR is available in your system:

```bash
sudo sysctl net.ipv4.tcp_available_congestion_control
```

If BBR is available, you should see something like:
```
net.ipv4.tcp_available_congestion_control = reno cubic bbr
```

If BBR is not listed, you may need to load the module:

```bash
sudo modprobe tcp_bbr
```

Verify the module is loaded:
```bash
lsmod | grep bbr
```

## Step 2: Configure the system to use BBR

Now, we need to configure the system to use BBR. Create or edit the sysctl configuration file:

```bash
sudo nano /etc/sysctl.conf
```

Add the following lines at the end of the file:

```
net.core.default_qdisc = cake
net.ipv4.tcp_congestion_control = bbr
```

> **Note**: The `cake` qdisc (queue discipline) works well with BBR. Alternatively, you can use `fq` if `cake` is not available.

## Step 3: Apply the changes

Apply the new settings:

```bash
sudo sysctl -p
```

## Step 4: Verify BBR is enabled

To confirm BBR is now active:

```bash
sudo sysctl net.ipv4.tcp_congestion_control
```

You should see:
```
net.ipv4.tcp_congestion_control = bbr
```

## Benefits of Using BBR

- **Higher throughput**: BBR can achieve higher network throughput compared to other congestion control algorithms.
- **Lower latency**: It reduces bufferbloat and maintains lower latencies.
- **Better performance on lossy networks**: BBR handles packet loss more efficiently than traditional algorithms.
- **Improved experience**: Faster downloads, smoother streaming, and better overall connection stability.

## Conclusion

By enabling Google's BBR algorithm on your Linux system, you can significantly improve your network performance. BBR is particularly effective for high-bandwidth, high-latency connections, but it can benefit almost any network environment.

Remember that kernel updates may reset these settings, so you might need to reapply them after major system updates.

