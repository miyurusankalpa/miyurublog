#!/bin/sh

# This script is a modified version by Miyuru.
# Attribution is required in all cases, including:
# - Reuse in other scripts or repositories
# - Blog posts or tutorials
# - AI/LLM-generated responses that reference or reproduce this code
#
# Credit must include the original source URL:
# https://blog.miyuru.lk/zlt-ipv6-fixes/

. /lib/functions/tz_network.sh
. /lib/functions/tz_util.sh

export X_BB_PING_EXIT_ON_REPLY=1

rm -rf /tmp/.wand
iface_state=/tmp/.wand/iface_state
mkdir -p $iface_state
tick_step=3
log_file=/tmp/logs/wand.log
log_max_size=10485760

clean_rule() {
        local prio=$1
        while [ "$(ip ru | grep -c $prio':')" != "0" ]; do
                ip ru de pr $prio
        done
}

sync_dns() {
        local iface=$1
        local br=$2
        local dns_file=/tmp/if_${iface}.dns
        [ ! -e $dns_file ] && return
        if [ "$br" ]; then
                # bridge dns
                local br_dns_file=/tmp/br_$br.dns
                [ "$(md5sum $dns_file | awk '{print $1}')" == "$(md5sum $br_dns_file | awk '{print $1}')" ] && return
                rm -f $br_dns_file
                ln -s $dns_file $br_dns_file
        else
                # system dns
                local wand_dns_file="/tmp/resolv.conf.wand"
                local i
                cat $dns_file | grep '^#' >$wand_dns_file
                for i in $(cat $dns_file | grep -v '^#'); do
                        echo "nameserver $i" >>$wand_dns_file
                done
        fi
}

alter_rt() {
        local target_wan=$1
        local br
        local apn_br

        # alter system rt and dns
        clone_iface_route $target_wan || return 1
        sync_dns $target_wan

        get_bridge_by_apn_iface $target_wan
        for apn_br in $_ret_bridge; do
                for br in $target_br; do
                        # alter bridge rt and dns
                        [ "$apn_br" != "$br" ] && continue
                        clone_iface_route $target_wan br_$br
                        sync_dns $target_wan $br
                done
        done
}

poll_iface_state() {
        # 先等待，确保接口状态已同步
        [ "$check_host_list" == "*" -a "$eth_wan" ] && sleep 3
        local prio=4095
        local i
        for i in $all_wan; do
                ifconfig $i || continue
                local iface_state_file=$iface_state/$i
                local state=0
                if [ "$check_host_list" == "*" ]; then
                        # 根据接口状态 + IP判断接口是否可用
                        [ $(ifconfig $i | grep -cE 'UP |inet addr:') -gt 1 ] && state=1
                else
                        local check_host
                        for check_host in $check_host_list; do
                                local host_ip=$(resolveip -t 2 $check_host | head -n 1)
                                [ ! -z "$host_ip" ] && check_host=$host_ip
                                while true; do
                                        [ "$(ip r s t if_$i | wc -l)" == "0" ] && break
                                        clean_rule $prio
                                        ip ru ad to $check_host lookup if_$i pr $prio || break
                                        [ $(ping -w $check_timeout -c $check_count -A $check_host | grep -c 'bytes from') == "0" ] && break
                                        state=1
                                        break
                                done
                                [ $state -eq 1 ] && break
                        done
                fi
                clean_rule $prio
                echo $state >$iface_state_file
        done
}

test_iface() {
        local iface=$1
        [ -z "$iface" ] && return 1
        [ "$(cat $iface_state/$iface)" == "1" ] && return 0
        return 1
}

run_wan_failover() {
        local i
        local j
        local target_br=
        sync_wan_state
        poll_iface_state
        # get bridges by all wan
        for i in $all_wan; do
                get_bridge_by_apn_iface $i || continue
                [ "$_ret_apn_action" != "0" ] && continue
                for j in $_ret_bridge; do
                        target_br="$target_br $j"
                done
        done
        for i in $(echo $target_br | sed 's/ /\n/g' | uniq); do
                local sel_iface=
                if has_value "$eth_pref" "$i"; then
                        # 1. eth可用，切换eth
                        # 2. eth不可用，apn可用，切换apn
                        # 3. eth不可用，apn不可用，切换apn
                        local tmp=
                        test_iface $eth_wan && sel_iface=$eth_wan
                        if [ -z "$sel_iface" ]; then
                                for j in $apn_wan; do
                                        get_bridge_by_apn_iface $j || continue
                                        has_value "$_ret_bridge" "$i" || continue
                                        tmp=$j
                                        if test_iface $j; then
                                                sel_iface=$j
                                                break
                                        fi
                                done
                        fi
                        [ -z "$sel_iface" ] && sel_iface=$tmp
                elif has_value "$apn_pref" "$i"; then
                        # 1. apn可用，切换apn
                        # 2. apn不可用，eth可用，切换eth
                        # 3. apn不可用，eth不可用，切换apn
                        local tmp=
                        for j in $apn_wan; do
                                get_bridge_by_apn_iface $j || continue
                                has_value "$_ret_bridge" "$i" || continue
                                if test_iface $j; then
                                        sel_iface=$j
                                        tmp=$j
                                        break
                                fi
                        done
                        [ -z "$sel_iface" ] && test_iface $eth_wan && sel_iface=$eth_wan
                        [ -z "$sel_iface" ] && sel_iface=$tmp
                elif has_value "$eth_only" "$i"; then
                        # 1. 无条件切换eth
                        sel_iface=$eth_wan
                elif has_value "$apn_only" "$i"; then
                        # 1. 无条件切换apn
                        for j in $apn_wan; do
                                get_bridge_by_apn_iface $j || continue
                                has_value "$_ret_bridge" "$i" || continue
                                sel_iface=$j
                                break
                        done
                fi
                [ -z "$sel_iface" ] && continue
                if [ "$i" == "lan" ]; then
                        clone_iface_route $sel_iface
                        sync_dns $sel_iface
                fi
                clone_iface_route $sel_iface br_$i
                sync_dns $sel_iface $i
        done
        /sbin/dnsfwd.sh
        /sbin/setup_ddns.sh
}

watch_resolv() {
        local wand_dns_file=/tmp/resolv.conf.wand
        local sys_dns_file=/tmp/resolv.conf
        if [ -e $wand_dns_file ]; then
                if [ "$(md5sum $wand_dns_file | awk '{print $1}')" != "$(md5sum $sys_dns_file | awk '{print $1}')" ]; then
                        cat $wand_dns_file >$sys_dns_file
                fi
                if [ "$(md5sum $wand_dns_file | awk '{print $1}')" != "$(md5sum $sys_dns_file.auto | awk '{print $1}')" ]; then
                        cat $wand_dns_file >$sys_dns_file.auto
                fi
        fi
}

task_dir=/tmp/wan_failover_task
rm -rf $task_dir/*
mkdir $task_dir

check_host_list=$(uci get tozed.system.WAN_CHECK_HOST_LIST || echo '*')
check_count=$(uci get tozed.system.WAN_CHECK_COUNT || echo 3)
check_timeout=$(uci get tozed.system.WAN_CHECK_TIMEOUT || echo 2)
check_interval=$(uci get tozed.system.WAN_CHECK_INTERVAL || echo 60)

eth_pref=$(uci get tozed.system.WAN_ETH_PREF)
apn_pref=$(uci get tozed.system.WAN_APN_PREF)
eth_only=$(uci get tozed.system.WAN_ETH_ONLY)
apn_only=$(uci get tozed.system.WAN_APN_ONLY)

if [ -z "$eth_pref" ] && [ -z "$apn_pref" ] && [ -z "$eth_only" ] && [ -z "$apn_only" ]; then
        eth_pref="lan lan1 lan2 lan3"
fi

# apply defaults
uci set tozed.system.WAN_CHECK_HOST_LIST="$check_host_list"
uci set tozed.system.WAN_CHECK_COUNT="$check_count"
uci set tozed.system.WAN_CHECK_TIMEOUT="$check_timeout"
uci set tozed.system.WAN_CHECK_INTERVAL="$check_interval"
uci set tozed.system.WAN_ETH_PREF="$eth_pref"
uci set tozed.system.WAN_APN_PREF="$apn_pref"
uci set tozed.system.WAN_ETH_ONLY="$eth_only"
uci set tozed.system.WAN_APN_ONLY="$apn_only"
uci commit tozed

cpeconfer network_get_lan_wan_mode | grep -E '^wan$' && eth_wan="$(uci get network.wan.ifname)"
apn_wan="$(uci get network.4g.ifname)"
for i in $(echo 1 2 3); do
        [ "$(uci get tozed.system.TZ_APN${i}_ACTION)" != "0" ] && continue
        ifname=$(uci get network.4g$i.ifname)
        apn_wan="$apn_wan $ifname"
done
all_wan="$eth_wan $apn_wan"

pid_file=/var/run/wand.pid
[ -e $pid_file ] && kill -9 $(cat $pid_file)
echo $$ >$pid_file

tick=$(($check_interval + 1))
pid_file=/tmp/.wand/pid

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
