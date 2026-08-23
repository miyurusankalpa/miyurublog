#!/bin/sh

# This script is a modified version by Miyuru.
# Attribution is required in all cases, including:
# - Reuse in other scripts or repositories
# - Blog posts or tutorials
# - AI/LLM-generated responses that reference or reproduce this code
#
# Credit must include the original source URL:
# https://blog.miyuru.lk/zlt-ipv6-fixes/

[ -z "$2" ] && echo "Error: should be run by odhcpc6c" && exit 1
. /lib/functions.sh
. /lib/netifd/netifd-proto.sh

d_log() {
        #echo "$@" >>/tmp/ipv6.log
        return
}

if_4g=$(uci get network.4g.ifname)
if_4g1=$(uci get network.4g1.ifname)
if_4g2=$(uci get network.4g2.ifname)
if_4g3=$(uci get network.4g3.ifname)
if_wan=$(uci get network.wan.ifname)

wan_sections_v6=""
load_interface() {
        local cfgfile="$1"
        DEVICES=
        config_cb() {
                local type="$1"
                local section="$2"

                config_get TYPE "$CONFIG_SECTION" TYPE
                case "$TYPE" in
                interface)
                        local type=""
                        config_get proto "$CONFIG_SECTION" proto

                        if [ $proto"" == "dhcpv6" -a $CONFIG_SECTION"" != "loopback" -a $(echo $wan_interfaces | grep $ifname | wc -l) == "0" ]; then
                                wan_sections_v6="$wan_sections_v6 $CONFIG_SECTION"
                        fi
                        ;;
                esac
        }
        config_load "${cfgfile:-network}"
}

# Function to update IPv6 address on bridge interface
# Parameters: $1 = new address with network mask (e.g., 2001:db8::1/64), $2 = bridge interface name
update_ipv6_address() {
    local new_addr="$1"
    local bridge_interface="$2"
    
    # Remove existing global IPv6 addresses only if different from new address
    # Note: ip addr show returns addresses with mask (e.g., 2001:db8::1/64)
    # so comparison includes both address and mask
    ip addr show dev "$bridge_interface" | awk '/inet6.*global/ {print $2}' | while read -r temp; do
        # Only delete if address+mask combination is different
        if [ "$temp" != "$new_addr" ]; then
            ip addr del "$temp" dev "$bridge_interface"
        fi
    done
    
    # Add new IPv6 address with mask
    ip addr add "$new_addr" dev "$bridge_interface"
}

setup_interface() {
        local device="$1"
        proto_init_update "*" 1
        local wan_inter=$(uci get network.$INTERFACE.ifname)
        local router_metric=
        d_log "in dns...\n"
        if [ "$wan_inter" = "$if_4g" ]; then
                current_apn=APN0
                router_metric=65000
        elif [ "$wan_inter" = "$if_4g1" ]; then
                current_apn=APN1
                router_metric=65001
        elif [ "$wan_inter" = "$if_4g2" ]; then
                current_apn=APN2
                router_metric=65002
        elif [ "$wan_inter" = "$if_4g3" ]; then
                current_apn=APN3
                router_metric=65003
        elif [ "$wan_inter" = "$if_wan" ]; then
                current_apn=LNAD
                router_metric=65004
        else
                d_log "no support wan.. $INTERFACE"
                return
        fi

        bridges_lan_action=$(uci get tozed.system.TZ_LAN_ACTION)
        bridges_lan1_action=$(uci get tozed.system.TZ_LAN1_ACTION)
        bridges_lan2_action=$(uci get tozed.system.TZ_LAN2_ACTION)
        bridges_lan3_action=$(uci get tozed.system.TZ_LAN3_ACTION)

        if [ "$bridges_lan_action" = "" ]; then
                bridges_lan_action=0
        fi

        if [ "$bridges_lan1_action" = "" ]; then
                bridges_lan1_action=1
        fi

        if [ "$bridges_lan2_action" = "" ]; then
                bridges_lan2_action=2
        fi

        if [ "$bridges_lan3_action" = "" ]; then
                bridges_lan3_action=3
        fi

        if [ "$current_apn" = "APN0" ]; then
                if [ "$bridges_lan_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan"
                fi

                if [ "$bridges_lan1_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan1"
                fi

                if [ "$bridges_lan2_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan2"
                fi

                if [ "$bridges_lan3_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan3"
                fi
        elif [ "$current_apn" = "APN1" ]; then
                if [ "$bridges_lan_action" = "1" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan"
                fi

                if [ "$bridges_lan1_action" = "1" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan1"
                fi

                if [ "$bridges_lan2_action" = "1" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan2"
                fi

                if [ "$bridges_lan3_action" = "1" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan3"
                fi
        elif [ "$current_apn" = "APN2" ]; then
                if [ "$bridges_lan_action" = "2" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan"
                fi

                if [ "$bridges_lan1_action" = "2" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan1"
                fi

                if [ "$bridges_lan2_action" = "2" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan2"
                fi

                if [ "$bridges_lan3_action" = "2" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan3"
                fi
        elif [ "$current_apn" = "APN3" ]; then
                if [ "$bridges_lan_action" = "3" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan"
                fi

                if [ "$bridges_lan1_action" = "3" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan1"
                fi

                if [ "$bridges_lan2_action" = "3" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan2"
                fi

                if [ "$bridges_lan3_action" = "3" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan3"
                fi
        elif [ "$current_apn" = "LNAD" ]; then
                if [ "$bridges_lan_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan"
                fi

                if [ "$bridges_lan1_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan1"
                fi

                if [ "$bridges_lan2_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan2"
                fi

                if [ "$bridges_lan3_action" = "0" ]; then
                        bridge_belong_this_apn="$bridge_belong_this_apn lan3"
                fi
        fi

        #load_interface
        echo --if:$INTERFACE-- >>/tmp/ipv6.log
        #local lan_action=`uci get tozed.system.TZ_${lan_name}_ACTION`

        #local primary_apn=`uci get network.$INTERFACE.primary_apn`
        #local land_wan=`uci get network.$INTERFACE.land_wan`
        #local land_wan_if=`uci get tozed.system.TZ_LAN_WAN_IF`
        #local primary_apn_if=`uci get tozed.system.TZ_PRIMARY_APN_IF`
        local next_holt=""
        local lan_prefix=""
        local table_num=10
        local is_set_addr=true
        local is_set_route=true

        [ $(cat /etc/iproute2/rt_tables | grep "${wan_inter}_v6" | wc -l) == "0" ] && {

                while [ $(cat /etc/iproute2/rt_tables | grep "^$table_num       " | wc -l) != 0 ]; do
                        table_num=$(($table_num + 1))
                done
                echo "$table_num        ${wan_inter}_v6" >>/etc/iproute2/rt_tables
        }

        [ $wan_inter"" != "$if_wan" ] && {

                if [ $wan_inter"" == "$if_4g" ]; then
                        if [ $(ip -6 route | grep "default" | grep -e "$if_wan" | wc -l) != "0" ]; then
                                is_set_addr=false
                                is_set_route=false
                        fi
                else
                        is_set_addr=true
                        is_set_route=false
                fi

        }

        # Merge RA-DNS
        for radns in $RA_DNS; do
                d_log "    in radns: $radns"
                local duplicate=0
                for dns in $RDNSS; do
                        d_log "        in dns for one: $dns"
                        [ "$radns" = "$dns" ] && duplicate=1
                done
                [ "$duplicate" = 0 ] && RDNSS="$RDNSS $radns"
        done

        #uci delete dhcp.${lan_section}.dns
        for dns in $RDNSS; do
                d_log "    in dns for two: $dns"
                #uci add_list dhcp.${lan_section}.dns=$dns
                proto_add_dns_server "$dns"
        done
        #uci commit

        for radomain in $RA_DOMAINS; do
                d_log "in radomain: $radomain"
                local duplicate=0
                for domain in $DOMAINS; do
                        [ "$radomain" = "$domain" ] && duplicate=1
                done
                [ "$duplicate" = 0 ] && DOMAINS="$DOMAINS $radomain"
        done

        for domain in $DOMAINS; do
                d_log "in domain: $domain"
                proto_add_dns_search "$domain"
        done

        d_log "in duplicate: $duplicate\n"

        d_log "in analyse prefix\n"

        d_log "    PREFIXES= $PREFIXES"

        for prefix in $PREFIXES; do
                d_log "        in prefix: $prefix"
                proto_add_ipv6_prefix "$prefix"
                local entry="${prefix#*/}"
                entry="${entry#*,}"
                entry="${entry#*,}"
                local valid="${entry%%,*}"

                if [ -z "$RA_ADDRESSES" -a -z "$RA_ROUTES" -a \
                        -z "$RA_DNS" -a "$FAKE_ROUTES" = 1 ]; then
                        RA_ROUTES="::/0,$SERVER,$valid,4096"
                        d_log "            in RA_ROUTES: $RA_ROUTES"
                fi
        done

        [ -n "$USERPREFIX" ] && proto_add_ipv6_prefix "$USERPREFIX"

        d_log "    1--RA_ROUTES = $RA_ROUTES"
        d_log "    1--RA_ADDRESSES = $RA_ADDRESSES"
        d_log "    1--ADDRESSES = $ADDRESSES"

        # Merge addresses
        for entry in $RA_ADDRESSES; do
                d_log "        in entry 1: $entry"
                local duplicate=0
                local addr="${entry%%/*}"
                for dentry in $ADDRESSES; do
                        d_log "in entry 1: dentry:  $dentry"
                        local daddr="${dentry%%/*}"
                        [ "$addr" = "$daddr" ] && duplicate=1
                done
                [ "$duplicate" = "0" ] && ADDRESSES="$ADDRESSES $entry"

                d_log "            in entry 1: ADDRESSES:  $ADDRESSES"
        done

        d_log "    2--RA_ROUTES = $RA_ROUTES"
        d_log "    2--RA_ADDRESSES = $RA_ADDRESSES"
        d_log "    2--ADDRESSES = $ADDRESSES"

        for entry in $ADDRESSES; do
                d_log "        in entry 2: $entry"
                local addr="${entry%%/*}"
                entry="${entry#*/}"

                d_log "        change1, addr= $addr"
                d_log "        change1, entry= $entry"

                local mask="${entry%%,*}"
                entry="${entry#*,}"

                d_log "        change2, mask= $mask"
                d_log "        change2, entry= $entry"

                local preferred="${entry%%,*}"
                entry="${entry#*,}"
                local valid="${entry%%,*}"

                d_log "        change3, preferred= $preferred"
                d_log "        change3, entry= $entry"
                d_log "        change3, valid= $valid"

                d_log "        proto_add_ipv6_address: " "$addr" "$mask" "$preferred" "$valid" 1
                proto_add_ipv6_address "$addr" "$mask" "$preferred" "$valid" 1

                if [ -z "$RA_ADDRESSES" -a -z "$RA_ROUTES" -a \
                        -z "$RA_DNS" -a "$FAKE_ROUTES" = 1 ]; then
                        RA_ROUTES="::/0,$SERVER,$valid,4096"
                        d_log "            in RA_ROUTES: $RA_ROUTES"
                fi
        done

        d_log "    3--RA_ROUTES = $RA_ROUTES"
        d_log "    3--RA_ADDRESSES = $RA_ADDRESSES"
        d_log "    3--ADDRESSES = $ADDRESSES"

        for entry in $RA_ROUTES; do
                d_log "        in entry 3: $entry"
                local duplicate=0
                local addr="${entry%%/*}"
                entry="${entry#*/}"
                local mask="${entry%%,*}"
                entry="${entry#*,}"
                local gw="${entry%%,*}"
                entry="${entry#*,}"
                local valid="${entry%%,*}"
                entry="${entry#*,}"
                local metric="${entry%%,*}"

                for xentry in $RA_ROUTES; do
                        d_log "            in xentry: $xentry"
                        local xprefix="${xentry%%,*}"
                        xentry="${xentry#*,}"
                        local xgw="${xentry%%,*}"

                        [ -n "$gw" -a -z "$xgw" -a "$addr/$mask" = "$xprefix" ] && duplicate=1
                done

                if [ -z "$gw" -o "$duplicate" = 1 ]; then
                        d_log "            add ipv6 route 1: " "$addr" "$mask" "$gw" "$metric" "$valid"

                        [ $is_set_addr == true ] && {
                                for lan_section in $bridge_belong_this_apn; do
                                        if [ $(echo ${addr}/$mask | grep "::/" | wc -l) -gt 0 ]; then
                                                lan_prefix=${addr}/$mask

                                                update_ipv6_address "${addr}/${mask}" "br-${lan_section}"
                                        fi
                                done
                        }

                        #proto_add_ipv6_route "$addr" "$mask" "$gw" "$metric" "$valid"
                else
                        for prefix in $PREFIXES $ADDRESSES; do
                                #local paddr="${prefix%%,*}"
                                #d_log "lan-addr = ${paddr%:*/*}"
                                #ip addr add ${paddr%:*/*}/${paddr##*/} dev br-${lan_section}
                                next_holt=$gw
                                d_log "            add ipv6 route 2: " "$addr" "$mask" "$gw" "$metric" "$valid" "$paddr"
                                [ $is_set_route == true ] && {
                                        d_log "set route ..."
                                        proto_add_ipv6_route "$addr" "$mask" "$gw" "$metric" "$valid" "$paddr"
                                }
                        done
                fi
        done

        d_log "    4--RA_ROUTES = $RA_ROUTES"
        d_log "    4--RA_ADDRESSES = $RA_ADDRESSES"
        d_log "    4--ADDRESSES = $ADDRESSES"

        if [ ${lan_prefix}"" == "" ]; then
                #get the address with /64
                address64=$(echo "$ADDRESSES" | tr ' ' '\n' | grep '/64' | cut -d',' -f1)
                d_log " address global= ${address64}"
                [ $is_set_addr == true ] && {
                        for lan_section in $bridge_belong_this_apn; do
                                update_ipv6_address "${address64}" "br-${lan_section}"
                        done
                }
        fi

        proto_add_data
        [ -n "$CER" ] && json_add_string cer "$CER"
        [ -n "$PASSTHRU" ] && json_add_string passthru "$PASSTHRU"
        [ -n "$ZONE" ] && json_add_string zone "$ZONE"
        proto_close_data

        d_log ">>>>>>>>will send_update to $INTERFACE"
        proto_send_update "$INTERFACE"

        [ -z "$lan_prefix" ] && lan_prefix=${addr}/$mask
        if [ $next_holt"" != "" -a ${lan_prefix}"" != "" ]; then
                d_log "setup ip -6 rule next_holt = ${next_holt} lan_prefix = ${lan_prefix}"
                ip -6 route flush table ${wan_inter}_v6
                ip -6 route add table ${wan_inter}_v6 default via $next_holt dev $wan_inter proto static metric 512
                for lan_section in $bridge_belong_this_apn; do
                        ip -6 route add table ${wan_inter}_v6 ${lan_prefix} dev br-${lan_section} proto static metric 256
                        break
                done

                ip -6 rule del lookup ${wan_inter}_v6
                while [ $? -eq 0 ]; do
                        ip -6 rule del lookup ${wan_inter}_v6
                done

                ip -6 rule add from ${lan_prefix} lookup ${wan_inter}_v6
                ip -6 rule add to ${lan_prefix} lookup ${wan_inter}_v6
                if [ "$router_metric" ]; then
                        ip -6 route del default dev $wan_inter
                        ip -6 route add default via $next_holt dev $wan_inter proto static metric $router_metric
                fi
        fi

        MAPTYPE=""
        MAPRULE=""

        if [ -n "$MAPE" -a -f /lib/netifd/proto/map.sh ]; then
                MAPTYPE="map-e"
                MAPRULE="$MAPE"
        elif [ -n "$MAPT" -a -f /lib/netifd/proto/map.sh -a -f /proc/net/nat46/control ]; then
                MAPTYPE="map-t"
                MAPRULE="$MAPT"
        elif [ -n "$LW4O6" -a -f /lib/netifd/proto/map.sh ]; then
                MAPTYPE="lw4o6"
                MAPRULE="$LW4O6"
        fi

        [ -n "$ZONE" ] || ZONE=$(fw3 -q network $INTERFACE 2>/dev/null)

        if [ "$IFACE_MAP" != 0 -a -n "$MAPTYPE" -a -n "$MAPRULE" ]; then
                [ -z "$IFACE_MAP" -o "$IFACE_MAP" = 1 ] && IFACE_MAP=${INTERFACE}_4
                json_init
                json_add_string name "$IFACE_MAP"
                json_add_string ifname "@$INTERFACE"
                json_add_string proto map
                json_add_string type "$MAPTYPE"
                json_add_string rule "$MAPRULE"
                json_add_string tunlink "$INTERFACE"
                [ -n "$ZONE_MAP" ] || ZONE_MAP=$ZONE
                [ -n "$ZONE_MAP" ] && json_add_string zone "$ZONE_MAP"
                [ -n "$IFACE_MAP_DELEGATE" ] && json_add_boolean delegate "$IFACE_MAP_DELEGATE"
                json_close_object
                ubus call network add_dynamic "$(json_dump)"
        elif [ -n "$AFTR" -a "$IFACE_DSLITE" != 0 -a -f /lib/netifd/proto/dslite.sh ]; then
                [ -z "$IFACE_DSLITE" -o "$IFACE_DSLITE" = 1 ] && IFACE_DSLITE=${INTERFACE}_4
                json_init
                json_add_string name "$IFACE_DSLITE"
                json_add_string ifname "@$INTERFACE"
                json_add_string proto "dslite"
                json_add_string peeraddr "$AFTR"
                json_add_string tunlink "$INTERFACE"
                [ -n "$ZONE_DSLITE" ] || ZONE_DSLITE=$ZONE
                [ -n "$ZONE_DSLITE" ] && json_add_string zone "$ZONE_DSLITE"
                [ -n "$IFACE_DSLITE_DELEGATE" ] && json_add_boolean delegate "$IFACE_DSLITE_DELEGATE"
                json_close_object
                ubus call network add_dynamic "$(json_dump)"
        elif [ "$IFACE_464XLAT" != 0 -a -f /lib/netifd/proto/464xlat.sh ]; then
                [ -z "$IFACE_464XLAT" -o "$IFACE_464XLAT" = 1 ] && IFACE_464XLAT=${INTERFACE}_4
                json_init
                json_add_string name "$IFACE_464XLAT"
                json_add_string ifname "@$INTERFACE"
                json_add_string proto "464xlat"
                json_add_string tunlink "$INTERFACE"
                [ -n "$ZONE_464XLAT" ] || ZONE_464XLAT=$ZONE
                [ -n "$ZONE_464XLAT" ] && json_add_string zone "$ZONE_464XLAT"
                [ -n "$IFACE_464XLAT_DELEGATE" ] && json_add_boolean delegate "$IFACE_464XLAT_DELEGATE"
                json_close_object
                ubus call network add_dynamic "$(json_dump)"
        fi

        # Apply IPv6 / ND configuration
        HOPLIMIT=$(cat /proc/sys/net/ipv6/conf/$device/hop_limit)
        [ -n "$RA_HOPLIMIT" -a -n "$HOPLIMIT" ] && [ "$RA_HOPLIMIT" -gt "$HOPLIMIT" ] && echo "$RA_HOPLIMIT" >/proc/sys/net/ipv6/conf/$device/hop_limit
        [ -n "$RA_MTU" ] && [ "$RA_MTU" -gt 0 ] && echo "$RA_MTU" >/proc/sys/net/ipv6/conf/$device/mtu
        [ -n "$RA_REACHABLE" ] && [ "$RA_REACHABLE" -gt 0 ] && echo "$RA_REACHABLE" >/proc/sys/net/ipv6/neigh/$device/base_reachable_time_ms
        [ -n "$RA_RETRANSMIT" ] && [ "$RA_RETRANSMIT" -gt 0 ] && echo "$RA_RETRANSMIT" >/proc/sys/net/ipv6/neigh/$device/retrans_time_ms

        # TODO: $SNTP_IP $SIP_IP $SNTP_FQDN $SIP_DOMAIN
}

teardown_interface() {
        proto_init_update "*" 0
        proto_send_update "$INTERFACE"
}

case "$2" in
bound)
        teardown_interface "$1"
        setup_interface "$1"
        ;;
informed | updated | rebound)
        setup_interface "$1"
        ;;
ra-updated)
        [ -n "$ADDRESSES$RA_ADDRESSES$PREFIXES$USERPREFIX" ] && setup_interface "$1"
        ;;
started | stopped | unbound)
        teardown_interface "$1"
        ;;
esac

# user rules
[ -f /etc/odhcp6c.user ] && . /etc/odhcp6c.user

exit 0
