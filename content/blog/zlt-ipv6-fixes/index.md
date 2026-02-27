---
title: Fixing IPv6 and Performance Issues on ZLT S12 Pro Router (OpenWrt)
date: "2026-02-26T18:17Z"
description: "I repaired the ZLT S12 Pro’s buggy OpenWrt firmware via telnet after ISP support fell short. By patching DHCPv6 scripts and killing a runaway logging process, I achieved stable IPv6 connectivity and lower system load."
draft: true
---

## Introduction

As mentioned in the [previous post](https://blog.miyuru.lk/s12-pro-ipv6-issue/), I reached out to the ISP to solve the issues, but only got feedback: *"The necessary corrections will be made by the technical team."*  
That didn't help, so I decided to take matters into my own hands after watching a YouTube video on gaining telnet access to the router.

> 📝 **Note:** I am using a ZLT S12 Pro router, and I have seen the same issues on the ZLT X25 PRO 5G. Most ZTE routers likely still use the same broken scripts.

> ⚠️ **Disclaimer:** These fixes are relatively harmless, but they might make your device unstable if applied incorrectly. Know what you are doing before applying the changes.

---

## Prerequisites: Get Telnet Access

You need to enable telnet on the router. The exact method may vary, but a quick search for your model should provide instructions.

**Hint:** You can find the steps for the S12 Pro model at the bottom of this article.

---

## Fix 1: Adjust IPv6 Router Lifetime

The first issue was that IPv6 router advertisements (RA) had too short a lifetime, causing clients to drop their IPv6 addresses frequently. Fix it by increasing `ra_lifetime` and enabling `ra_useleasetime`:

```bash
uci set dhcp.lan.ra_lifetime='1800'
uci set dhcp.lan.ra_useleasetime='1'
uci commit dhcp
/etc/init.d/odhcpd restart
```

Reference: [OpenWrt DHCP Configuration](https://openwrt.org/docs/guide-user/base-system/dhcp)

You can verify the change with `rdisc6`. After the fix, the RA output router lifetime of 1800 seconds:

---

## Fix 2: DHCPv6 Script Improvements

The main IPv6 problems stem from a broken DHCPv6 script. It mishandles preferred and valid lifetimes and unnecessarily removes all global IPv6 addresses on each run.

### 2.1 Fixing Preferred and Valid Lifetimes

The router tries to implement a custom version of [RFC 7278](https://datatracker.ietf.org/doc/html/rfc7278). From testing, the valid and preferred lifetimes are taken from the IPv6 prefix assigned to the `br-lan` interface. The script at `/lib/netifd/dhcpv6.script` contains these problematic lines:

**Always take a backup before making changes:**

```bash
cp /lib/netifd/dhcpv6.script /lib/netifd/dhcpv6.script.bak
```

```bash
addr_pref=$(echo $ADDRESSES | cut -d ',' -f 2)
[ $addr_pref -gt 240 ] && addr_pref=240
addr_valid=$(echo $ADDRESSES | cut -d ',' -f 3)
[ $addr_valid -gt 300 ] && addr_valid=300
ip addr add ${addr}/$mask dev br-${lan_section} preferred_lft $addr_pref valid_lft $addr_valid
```

The script caps the preferred lifetime at 240 seconds and the valid lifetime at 300 seconds, which is far too short. To solve this, we can simply remove those lines and let the router use the default values (86400 seconds). Alternatively, set static high values.

**Fix:** Comment out or delete those lines, and use a simpler `ip addr add` without explicit lifetimes.

After this change, the router will assign proper lifetimes, as seen in the `rdisc6` output below.

```bash
Soliciting ff02::2 (ff02::2) on wlp0s20f3...

Hop limit                 :           64 (      0x40)
Stateful address conf.    :           No
Stateful other conf.      :          Yes
Mobile home agent         :           No
Router preference         :       medium
Neighbor discovery proxy  :           No
Router lifetime           :         1800 (0x00000708) seconds
Reachable time            :  unspecified (0x00000000)
Retransmit time           :  unspecified (0x00000000)
 Source link-layer address: 98:A9:42:9C:68:21
 MTU                      :         1500 bytes (valid)
 Prefix                   : 2001:db8:a400:2e76::/64
  On-link                 :          Yes
  Autonomous address conf.:          Yes
  Valid time              :        86400 (0x00015180) seconds
  Pref. time              :        86400 (0x00015180) seconds
 Recursive DNS server     : 2001:db8:a400:2e76:60b9:9aff:fe2d:b1e
  DNS server lifetime     :         1800 (0x00000708) seconds
```

### 2.2 Preventing Unnecessary Address Deletion

Even after fixing lifetimes, disconnections still occurred because of this loop in the same script:

```bash
for temp in $(ip addr show dev br-${lan_section} | grep inet6 | grep global | awk '{print $2}'); do
    ip addr del $temp dev br-${lan_section}
done
```

It removes **all** global IPv6 addresses every time the script runs, which is why IPv6 disconnected from time to time. 
The better way is to remove addresses that differ from the new one being added.

I replaced that block with a new function:

```bash
# Function to update IPv6 address on bridge interface
# Parameters: $1 = new address (with mask), $2 = bridge interface name
update_ipv6_address() {
    local new_addr="$1"
    local bridge_interface="$2"
    
    # Remove existing global IPv6 addresses only if different from new address
    # Combined grep|grep|awk into single awk for better performance
    ip addr show dev "$bridge_interface" | awk '/inet6.*global/ {print $2}' | while read -r temp; do
        # Only delete if address is different from the one we're adding
        if [ "$temp" != "$new_addr" ]; then
            ip addr del "$temp" dev "$bridge_interface"
        fi
    done
    
    # Add new IPv6 address
    ip addr add "$new_addr" dev "$bridge_interface"
}
```

**Hint:** You can find the complete modified script for the S12 Pro model at the bottom of this article.

Replace the old deletion+addition code with a call to this function. After updating the script, IPv6 addresses persist correctly.

---

## Fix 3: Disable NAT66 Masquerade

Even after fixing disconnections, I noticed that all devices behind the router appeared to have the same public IPv6 address. The router was performing NAT66 on the `br-lan` interface. We can confirm this with:

```bash
ip6tables -t nat -vnL --line-numbers
```

Example output:

```
Chain POSTROUTING (policy ACCEPT 21 packets, 1763 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1      112 51586 MASQUERADE  all      *      usb0    ::/0                 ::/0   
```

The masquerade rule was added by a script at `/usr/lib/lua/tz/firewall.sh` via var with a comment *"fix temporary broken ipv6"*. This is the relevant section:

```bash
if [ $main_apn_nat -eq 1 ]; then
    for temp_if in $(uci get network.4g.ifname); do
        iptables -w -t nat -A POSTROUTING -o $temp_if -j MASQUERADE
        [ "$ipv6_masq" ] && ip6tables -w -t nat -A POSTROUTING -o $temp_if -j MASQUERADE
    done
fi
```

To permanently disable IPv6 masquerade, we can set the `$ipv6_masq` variable to empty and reboot:

**Backup first:**

```bash
cp /usr/lib/lua/tz/firewall.sh /usr/lib/lua/tz/firewall.sh.bak
```

```bash
sed -i 's/ipv6_masq=1/ipv6_masq=/g' /usr/lib/lua/tz/firewall.sh
```

To apply immediately without reboot, delete the NAT rule:

```bash
ip6tables -t nat -D POSTROUTING 1
```

Now each device gets its own global IPv6 address as intended.

---

## Bonus: Reduce System Load by Fixing wand Logging

During debugging, I noticed the router's load average was constantly around 1. A quick `top` showed a `wc -c` process eating CPU:

```
2834  2833 root     R     1380   1%  23% wc -c /tmp/logs/wand.log
```

The log file `/tmp/logs/wand.log` had grown huge. This logging comes from the script `/bin/wand`. The original script continuously appends to the log and also checks its size for rotation, using `wc -c` which reads the entire file each time—expensive on a large file.

**Fix:** Comment out all logging and log‑rotation lines. Here’s the modified portion of the script:

**Backup first:**

```bash
cp /bin/wand /bin/wand.bak
```

```bash
# Initial startup log - COMMENTED OUT
# echo "wand started at[$(cat /proc/uptime | cut -d ' ' -f 1)], pid[$$]" >>$log_file

while true; do
        # Write current process ID to PID file for tracking
        echo $$ >$pid_file
        
        # Update last active timestamp (system uptime in seconds)
        cat /proc/uptime | awk -F '.' '{print $1}' >/tmp/.wand/last_active
        
        # Debug output - COMMENTED OUT
        # set -x
        # cat /proc/uptime
        
        # Create timeout task if tick counter exceeds check interval
        if [ $tick -gt $check_interval ]; then
                touch $task_dir/timeout
        fi
        
        # Process all pending tasks in task directory
        while true; do
                no_task=1
                for i in $(ls $task_dir 2>/dev/null); do
                        # Remove task file and execute failover
                        rm -rf $task_dir/$i
                        run_wan_failover
                        
                        # Reset tick counter after task execution
                        tick=0
                        no_task=0
                        break
                done
                # Exit loop if no tasks found
                [ $no_task -eq 1 ] && break
        done
        
        # Monitor DNS resolver configuration
        watch_resolv
        
        # Increment tick counter and wait
        tick=$(($tick + $tick_step))
        sleep $tick_step
        
        # Debug output end - COMMENTED OUT
        # set +x
        
        # Log rotation logic - COMMENTED OUT (not needed without logging)
        # log_size=$(wc -c $log_file 2>/dev/null | awk '{print $1}')
        # [ -z "$log_size" ] && log_size=0
        # if [ $log_size -gt $log_max_size ]; then
        #         rm -f $pid_file
        #         gzip -kf $log_file
        #         >$log_file
        # fi
        
done # Removed: >>$log_file 2>&1 (log redirection commented out)
```

**Hint:** The complete modified `wand` script for the S12 Pro is available at the bottom of this article.

After editing the file, restart the service:

```bash
/etc/init.d/wand restart
```

The load average dropped back to normal.

---

## Persistence

All script changes made are permanent and survive a reboot. Reset will revert only the configs set via `uci` (Fix 1).


## Conclusion

After applying these changes, the router became much more stable, and IPv6 now works as intended on all devices. Most of the problems stem from the fact that there is no proper DHCP‑PD for end devices, and [ISPs are still trying to apply legacy v4 practices to IPv6](https://blog.miyuru.lk/server-provider-deploy-ipv6-correctly/). Hopefully, this situation will improve in the future.

## Resources

> **❗ Always make a copy of the original files before applying any modifications, and compare the differences to understand the changes.**

- Modified scripts for ZLT S12 Pro:
  - `newdhcpv6.sh` (link)
  - `newwand.sh` (link)
  - `howtotelnet.txt` (link)

This took 2 days of research and testing. If you found this helpful, consider supporting me via [here](https://donate.stripe.com/00wdR98qH1vR41yfxKbfO01). Please add a note about this blog post so I know it’s from here.

