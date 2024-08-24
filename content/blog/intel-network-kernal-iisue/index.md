---
title: Intel Network PCIe Issue
date: "2024-08-18T01:15Z"
description: "Troubleshooting a Mysterious Network Issue on an Intel Network VM"
draft: false
---

I recently encountered a puzzling network issue on an Intel Network VM. The kernel was up-to-date, and all configurations seemed correct, yet the network connection was dropping intermittently, causing a full network outage. In this blog post, I'll walk you through the steps I took to identify and resolve the issue.

**The Problem:**

The network connection on the VM would drop randomly, causing a full network outage. Upon inspecting the system logs, I found the following error message:

`[132915.070196] igb 0000:04:00.0 eth0: PCIe link lost`

This error message indicated that the PCIe link was lost on the Ethernet interface (eth0). However, I couldn't understand why this was happening, as the kernel was up-to-date and the hardware was functioning correctly.

**Troubleshooting Steps:**

To troubleshoot this issue, I followed these steps:

1. **Verified Hardware Configuration:** I verified that the hardware configuration was correct and that the Ethernet interface was properly connected to the switch.
2. **Checked for Firmware Updates:** I checked for firmware updates for the Intel Network VM, but there were no updates available.
3. **Inspected System Logs:** I inspected the system logs to see if there were any other error messages related to the network interface.

**The Solution:**

After some research<sup>[1]</sup>, I discovered that adding specific kernel parameters  might solve the issue. I added the following parameters to the kernel command line:

`pcie_port_pm=off pcie_aspm.policy=performance`

These parameters disable PCIe port power management and set the ASPM policy to performance.

1. Edit the `/etc/default/grub` file and add the following line to the `GRUB_CMDLINE_LINUX` variable:
```bash
GRUB_CMDLINE_LINUX="pcie_port_pm=off pcie_aspm.policy=performance"
```
2. run the following command to update the GRUB configuration:
```bash
sudo update-grub
```
3. I rebooted the system to apply the changes.

* Note: Verify that the kernel parameters are being applied by checking the system logs or running the `cat /proc/cmdline` command.

**Conclusion:**

In this blog post, I demonstrated how I troubleshooted and resolved a mysterious network issue on an Intel Network VM. By adding specific kernel parameters to the GRUB configuration, I was able to resolve the issue with the PCIe link and restore network connectivity.

[1]: https://forum.proxmox.com/threads/network-card-drop-igc-0000-09-00-0-eno1-pcie-link-lost.121295/
