#!/bin/sh

# This script is a modified version by Miyuru.
# Attribution is required in all cases, including:
# - Reuse in other scripts or repositories
# - Blog posts or tutorials
# - AI/LLM-generated responses that reference or reproduce this code
#
# Credit must include the original source URL:
# https://blog.miyuru.lk/zlt-ipv6-fixes/

ipt_log=/dev/null

[ -e /root/debug_firewall ] && ipt_log=/tmp/fw_$(cat /proc/uptime | cut -d ' ' -f 1)_$$.log

(
        set -x

        not_ready=0
        for i in $(echo lan lan1 lan2 lan3); do
                [ "$(uci get network.$i.disabled)" == "1" ] && continue
                ifconfig br-$i | grep 'inet addr' || not_ready=1
        done
        [ $not_ready -eq 1 ] && echo 'interface not ready' && exit 0

        lock_file=/tmp/.firewall_running

        [ -e $lock_file ] && echo 'firewall already running!' && exit 0

        touch $lock_file

        REMOTE_MINI_HTTP_LISTEN_PORT=$(cfg -g TZ_HTTP_PORT --section web)
        REMOTE_MINI_HTTPS_LISTEN_PORT=$(cfg -g TZ_HTTPS_PORT --section web)
        TZ_HTTP_REMOTE_ENABLE=$(cfg -g TZ_HTTP_REMOTE_ENABLE --section web)
        TZ_REMOTE_LOGIN=$(cfg -g TZ_REMOTE_LOGIN --section remote_control)
        TZ_REMOTE_DEFAULT_LIST=$(cfg -g TZ_REMOTE_DEFAULT_LIST --section remote_control)
        TZ_REMOTE_LOGIN_LIST=$(cfg -g TZ_REMOTE_LOGIN_LIST --section remote_control)
        TZ_REMOTE_PING=$(cfg -g TZ_REMOTE_PING --section remote_control)
        TZ_REMOTE_PING_LIST=$(cfg -g TZ_REMOTE_PING_LIST --section remote_control)
        TZ_REMOTE_PING_LIST_INHERIT=$(cfg -g TZ_REMOTE_PING_LIST_INHERIT --section remote_control)
        TZ_REMOTE_DEFAULT_LIST_AUTH=$(cfg -g TZ_REMOTE_DEFAULT_LIST_AUTH --section remote_control)
        TZ_DMZ_ENABLE=$(cfg -g TZ_DMZ_ENABLE --section dmz)

        FIREWALL_FILTER_RULE_FILE="/etc/firewall.user"
        FIREWALL_URL_DNS_FILTER_PREX="URL-DNS-FILTER"
        FIREWALL_URL_DNS_FILTER_FOR_WIFI_PREX="URL-DNS-FOR-WIFI-FILTER"
        FIREWALL_FILTER_PREX_LIST="
FORWARD-DEFAULT-ACTION
SPEED-LIMIT-FILTER
MAC-DEFAULT-ACTION
URL-DEFAULT-ACTION
URL-FILTER
URL-FOR-WIFI-FILTER
PORT-REDIRECT
PORT-FILTER
IP-FILTER
ACL-FILTER
MAC-FILTER
IP-MAC-BIND-FILTER
"

        # temporary fix for broken IPv6 function
        ipv6_masq=0

        post_script=/tmp/firewall.d/
        mkdir -p $post_script

        # dump upnp rules
        upnp_dump_file=/tmp/upnp_dump
        upnp_restore_file=$post_script/upnp_restore
        rm -rf $upnp_dump_file
        rm -rf $upnp_restore_file
        echo "#!/bin/sh" >$upnp_restore_file
        for i in $(echo raw mangle filter nat); do
                iptables -w -t $i -S MINIUPNPD >$upnp_dump_file
                while read ln; do
                        echo "iptables -w -t $i $ln" >>$upnp_restore_file
                done <$upnp_dump_file
        done
        chmod +x $upnp_restore_file

        for i in $(echo raw mangle filter nat); do
                iptables -w -t $i -F
                ip6tables -w -t $i -F
        done

        for i in $(echo INPUT FORWARD OUTPUT); do
                iptables -w -P $i ACCEPT
                ip6tables -w -P $i ACCEPT
        done

        blackhole='169.254.169.254'
        ip route del $blackhole
        ip route add blackhole $blackhole

        ebtables -F

        WAN_ENABLE_HTTP=1
        [ "$REMOTE_MINI_HTTP_LISTEN_PORT" == "0" -o -z "$REMOTE_MINI_HTTP_LISTEN_PORT" ] && WAN_ENABLE_HTTP=0
        [ "$TZ_REMOTE_LOGIN" != "1" ] && WAN_ENABLE_HTTP=0

        # 如果配置了启用HTTP，用户即使不填写端口也开启
        [ "$TZ_HTTP_REMOTE_ENABLE" == "1" -a "$WAN_ENABLE_HTTP" == "0" ] && {
                WAN_ENABLE_HTTP=1
                REMOTE_MINI_HTTP_LISTEN_PORT=80
        }

        WAN_ENABLE_HTTPS=1
        [ "$TZ_REMOTE_LOGIN" != "1" ] && WAN_ENABLE_HTTPS=0

        WAN_REDIRECT_HTTP=0
        [ "$REMOTE_MINI_HTTP_LISTEN_PORT" != "80" -a "$REMOTE_MINI_HTTP_LISTEN_PORT" != "0" -a "$REMOTE_MINI_HTTP_LISTEN_PORT" ] && WAN_REDIRECT_HTTP=1

        WAN_REDIRECT_HTTPS=0
        [ "$REMOTE_MINI_HTTPS_LISTEN_PORT" != "443" -a "$REMOTE_MINI_HTTPS_LISTEN_PORT" != "0" -a "$REMOTE_MINI_HTTPS_LISTEN_PORT" ] && WAN_REDIRECT_HTTPS=1

        lan_ip=$(uci get network.lan.ipaddr)
        lan1_ip=$(uci get network.lan1.ipaddr)
        lan2_ip=$(uci get network.lan2.ipaddr)
        lan3_ip=$(uci get network.lan3.ipaddr)

        wan_iface=$(uci get network.wan.ifname)
        main_apn_iface=$(uci get network.4g.ifname)
        aux_apn_iface=

        for i in $(echo 4g 4g1 4g2 4g3); do
                apn_iface=$(uci get network.$i.ifname)
                [ -z "$apn_iface" ] && continue
                ifconfig $apn_iface || continue
                wan_iface="$wan_iface $apn_iface"
                [ "$i" == "4g" ] && continue
                aux_apn_iface="$aux_apn_iface $apn_iface"
        done

        echo wan_iface $wan_iface
        echo main_apn_iface $main_apn_iface
        echo aux_apn_iface $aux_apn_iface

        lan_iface=
        for i in $(echo lan lan1 lan2 lan3); do
                ifconfig br-$i || continue
                [ -z "$lan_iface" ] && lan_iface=$i && continue
                lan_iface="$lan_iface $i"
        done

        echo lan_iface $lan_iface

        defense_attack() {
                #       syn_flood
                iptables -w -N syn_flood
                iptables -w -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j syn_flood
                iptables -w -A syn_flood -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m limit --limit 25/sec --limit-burst 50 -j RETURN
                iptables -w -A syn_flood -j DROP

                ip6tables -w -N syn_flood
                ip6tables -w -A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j syn_flood
                ip6tables -w -A syn_flood -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m limit --limit 25/sec --limit-burst 50 -j RETURN
                ip6tables -w -A syn_flood -j DROP

                #       Ping洪水攻击（Ping of Death）
                #iptables -w -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
                #iptables -w -A INPUT -p icmp -j DROP

                #       LAND ATTACK:
                #       iptables -w -A INPUT -s 127.0.0.0/8 -j DROP

                for i in $aux_apn_iface; do
                        local ip_addr=$(ifconfig ${i} | grep 'inet addr' | awk -F ':' '{print $2}' | awk '{print $1}')
                        [ -z "$ip_addr" ] && continue
                        iptables -w -A INPUT -s $ip_addr -j DROP
                done

                #       DOC:
                iptables -w -A INPUT -p tcp --syn -m connlimit --connlimit-above 150 -j DROP
                ip6tables -w -A INPUT -p tcp --syn -m connlimit --connlimit-above 150 -j DROP
                #iptables -w -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT

                #       XMAS Packet:

                iptables -w -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
                ip6tables -w -A INPUT -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP
                #       NMAP FIN/URG/PSH
                iptables -w -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
                ip6tables -w -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP

                #       Xmas Tree
                iptables -w -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
                ip6tables -w -A INPUT -p tcp --tcp-flags ALL ALL -j DROP

                #       Another Xmas Tree
                iptables -w -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP
                ip6tables -w -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

                #       Null Scan(possibly)
                iptables -w -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
                ip6tables -w -A INPUT -p tcp --tcp-flags ALL NONE -j DROP

                #       SYN/RST
                iptables -w -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
                ip6tables -w -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
        }

        set_nat_mode_rule() {
                # NAT mode enable

                # main apn
                local apn_config="$(uci get tozed.modem.TZ_DIALTOOL2_APN_SelectConfig)"
                local main_apn_nat=0
                if [ "$apn_config" == "Production" -o -z "$apn_config" ]; then
                        if [ "$(uci get tozed.modem.TZ_DIALTOOL2_NAT)" != "disable" ]; then
                                main_apn_nat=1
                        fi
                elif [ "$apn_config" == "Staging" ]; then
                        if [ "$(uci get tozed.modem.TZ_DIALTOOL2_NAT_SLAB)" != "disable" ]; then
                                main_apn_nat=1
                        fi
                elif [ "${apn_config:0:3}" == "Aux" ]; then
                        if [ "$(uci get tozed.modem.TZ_DIALTOOL2_NAT_AUX${apn_config:3})" != "disable" ]; then
                                main_apn_nat=1
                        fi
                fi

                if [ $main_apn_nat -eq 1 ]; then
                        for temp_if in $(uci get network.4g.ifname); do
                                iptables -w -t nat -A POSTROUTING -o $temp_if -j MASQUERADE
                                [ "$ipv6_masq" ] && ip6tables -w -t nat -A POSTROUTING -o $temp_if -j MASQUERADE
                        done
                fi

                if [ "$(cpeconfer network_get_lan_wan_mode | grep -v mode)" == "wan" ]; then
                        wan_if="eth0.2"
                        iptables -w -t nat -A POSTROUTING -o $wan_if -j MASQUERADE
                        [ "$ipv6_masq" ] && ip6tables -w -t nat -A POSTROUTING -o $wan_if -j MASQUERADE
                        is_pppoe=$(uci get network.wan.proto)
                        if [ "$is_pppoe" == "pppoe" ]; then
                                iptables -w -t nat -A POSTROUTING -o pppoe-wan -j MASQUERADE
                                [ "$ipv6_masq" ] && ip6tables -w -t nat -A POSTROUTING -o pppoe-wan -j MASQUERADE
                        fi
                fi

                for x in $(echo 1 2 3); do
                        [ "$(uci get tozed.modem.TZ_MUTILAPN${x}_ENABLE)" != "1" ] && continue
                        [ "$(uci get tozed.modem.TZ_MUTILAPN${x}_NAT)" == "disable" ] && continue
                        apn_iface=$(uci get network.4g$x.ifname)
                        [ -z "$apn_iface" ] && continue
                        iptables -w -t nat -A POSTROUTING -o $apn_iface -j MASQUERADE
                        [ "$ipv6_masq" ] && ip6tables -w -t nat -A POSTROUTING -o $apn_iface -j MASQUERADE
                done

                for x in $(echo 1 2 3 4); do
                        [ "$(uci get network.vpn$x.auto)" != "1" ] && continue
                        vpn_iface=$(uci get network.vpn$x.ifname)
                        [ -z "$vpn_iface" ] && continue
                        iptables -w -t nat -A POSTROUTING -o $vpn_iface -j MASQUERADE
                        [ "$ipv6_masq" ] && ip6tables -w -t nat -A POSTROUTING -o $vpn_iface -j MASQUERADE
                done
        }

        redirect_wan() {
                for wan in $wan_iface; do
                        local wan_ip=$(ifconfig $wan | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}')
                        [ -z "$wan_ip" ] && continue
                        if [ "$WAN_ENABLE_HTTP" == "1" ]; then
                                if [ "$WAN_REDIRECT_HTTP" == "1" ]; then
                                        iptables -w -t nat -I PREROUTING -i $wan -p tcp -d $wan_ip --dport $REMOTE_MINI_HTTP_LISTEN_PORT -j REDIRECT --to-ports 80
                                else
                                        iptables -w -t nat -I PREROUTING -i $wan -p tcp -d $wan_ip --dport $REMOTE_MINI_HTTP_LISTEN_PORT -j ACCEPT
                                fi
                        fi
                        if [ "$WAN_ENABLE_HTTPS" == "1" ]; then
                                if [ "$WAN_REDIRECT_HTTPS" == "1" ]; then
                                        iptables -w -t nat -I PREROUTING -i $wan -p tcp -d $wan_ip --dport $REMOTE_MINI_HTTPS_LISTEN_PORT -j REDIRECT --to-ports 443
                                else
                                        iptables -w -t nat -I PREROUTING -i $wan -p tcp -d $wan_ip --dport $REMOTE_MINI_HTTPS_LISTEN_PORT -j ACCEPT
                                fi
                        fi
                done
        }

        redirect_wan_blackhole() {
                for wan in $wan_iface; do
                        local wan_ip=$(ifconfig $wan | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}')
                        [ -z "$wan_ip" ] && continue
                        if [ "$WAN_REDIRECT_HTTP" == "1" -a "$WAN_ENABLE_HTTP" == "1" ]; then
                                iptables -w -t nat -I PREROUTING -i $wan -p tcp -d $wan_ip --dport 80 -j DNAT --to $blackhole
                        fi
                        if [ "$WAN_REDIRECT_HTTPS" == "1" -a "$WAN_ENABLE_HTTPS" == "1" ]; then
                                iptables -w -t nat -I PREROUTING -i $wan -p tcp -d $wan_ip --dport 443 -j DNAT --to $blackhole
                        fi
                done
        }

        drop_wan() {
                for wan in $wan_iface; do
                        iptables -w -I INPUT -i $wan -p tcp --dport 80 -j DROP
                        ip6tables -w -I INPUT -i $wan -p tcp --dport 80 -j DROP
                        iptables -w -I INPUT -i $wan -p tcp --dport 443 -j DROP
                        ip6tables -w -I INPUT -i $wan -p tcp --dport 443 -j DROP
                done
        }

        turn_off_remote_web_login() {
                drop_wan
                [ "${TZ_REMOTE_DEFAULT_LIST_AUTH}" != "1" ] && return
                for ip in $TZ_REMOTE_DEFAULT_LIST; do
                        [ -z "$ip" ] && continue
                        [ "$WAN_ENABLE_HTTP" == "1" ] && {
                                iptables -w -I INPUT -s $ip -p tcp --dport 80 -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p tcp --dport 80 -j ACCEPT
                        }
                        [ "$WAN_ENABLE_HTTPS" == "1" ] && {
                                iptables -w -I INPUT -s $ip -p tcp --dport 443 -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p tcp --dport 443 -j ACCEPT
                        }
                done
        }

        turn_on_remote_web_login() {
                drop_wan

                for ip in $TZ_REMOTE_DEFAULT_LIST; do
                        [ -z "$ip" ] && continue
                        if [ $ip'' == '0.0.0.0' ]; then
                                [ "$WAN_ENABLE_HTTP" == "1" ] && {
                                        iptables -w -I INPUT -p tcp --dport 80 -j ACCEPT
                                        ip6tables -w -I INPUT -p tcp --dport 80 -j ACCEPT
                                }
                                [ "$WAN_ENABLE_HTTPS" == "1" ] && {
                                        iptables -w -I INPUT -p tcp --dport 443 -j ACCEPT
                                        ip6tables -w -I INPUT -p tcp --dport 443 -j ACCEPT
                                }
                                break
                        fi
                        [ "$WAN_ENABLE_HTTP" == "1" ] && {
                                iptables -w -I INPUT -s $ip -p tcp --dport 80 -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p tcp --dport 80 -j ACCEPT
                        }
                        [ "$WAN_ENABLE_HTTPS" == "1" ] && {
                                iptables -w -I INPUT -s $ip -p tcp --dport 443 -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p tcp --dport 443 -j ACCEPT
                        }
                done

                for ip in $TZ_REMOTE_LOGIN_LIST; do
                        [ -z "$ip" ] && continue
                        [ "$WAN_ENABLE_HTTP" == "1" ] && {
                                iptables -w -I INPUT -s $ip -p tcp --dport 80 -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p tcp --dport 80 -j ACCEPT
                        }
                        [ "$WAN_ENABLE_HTTPS" == "1" ] && {
                                iptables -w -I INPUT -s $ip -p tcp --dport 443 -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p tcp --dport 443 -j ACCEPT
                        }
                done
        }

        turn_off_remote_ping() {

                for wan in $wan_iface; do
                        [ -z "$wan" ] && continue
                        iptables -w -I INPUT -i $wan -p icmp --icmp-type 8 -j DROP
                        ip6tables -w -I INPUT -i $wan -p icmp --icmp-type 8 -j DROP
                done

                if [ "${TZ_REMOTE_DEFAULT_LIST_AUTH}" = "1" ]; then
                        for ip in $TZ_REMOTE_DEFAULT_LIST; do
                                [ -z "$ip" ] && continue
                                iptables -w -I INPUT -s $ip -p icmp -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p icmp -j ACCEPT
                        done
                fi
        }

        turn_on_remote_ping() {

                for wan in $wan_iface; do
                        [ -z "$wan" ] && continue
                        iptables -w -I INPUT -i $wan -p icmp --icmp-type 8 -j DROP
                        ip6tables -w -I INPUT -i $wan -p icmp --icmp-type 8 -j DROP
                done

                [ "$TZ_REMOTE_PING_LIST_INHERIT" != "0" ] && {
                        for ip in $TZ_REMOTE_DEFAULT_LIST; do
                                [ -z "$ip" ] && continue
                                iptables -w -I INPUT -s $ip -p icmp -j ACCEPT
                                ip6tables -w -I INPUT -s $ip -p icmp -j ACCEPT
                        done
                }

                for ip in $TZ_REMOTE_PING_LIST; do
                        [ -z "$ip" ] && continue
                        iptables -w -I INPUT -s $ip -p icmp -j ACCEPT
                        ip6tables -w -I INPUT -s $ip -p icmp -j ACCEPT
                done
        }

        set_dmz() {

                #iptables -w -I PREROUTING -t nat -i  br-lan -d 10.23.16.11 -j DNAT --to-destination 192.168.2.111
                #iptables -w -I POSTROUTING -d 192.168.2.111  -j MASQUERADE

                local host_ip=$(cfg -g TZ_DMZ_HOST_IP --section dmz)
                [ $host_ip"" == "" ] && RETURN

                # wan
                if true; then
                        local wan="eth0.2"
                        local wan_ip=$(ifconfig $wan | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}')
                        if [ "${wan_ip}" != "" ]; then
                                iptables -w -t nat -I PREROUTING -i $wan -d $wan_ip -j DNAT --to-destination $host_ip
                                for i in $lan_iface; do
                                        iptables -w -t nat -I PREROUTING -i br-$i -d $wan_ip -j DNAT --to-destination $host_ip
                                done
                        fi
                fi

                # main apn
                local apn_config="$(uci get tozed.modem.TZ_DIALTOOL2_APN_SelectConfig)"
                local main_apn_nat=0
                if [ "$apn_config" == "Production" -o -z "$apn_config" ]; then
                        if [ "$(cfg -g TZ_DIALTOOL2_NAT --section modem)" != "disable" ]; then
                                main_apn_nat=1
                        fi
                elif [ "$apn_config" == "Staging" ]; then
                        if [ "$(cfg -g TZ_DIALTOOL2_NAT_SLAB --section modem)" != "disable" ]; then
                                main_apn_nat=1
                        fi
                elif [ "${apn_config:0:3}" == "Aux" ]; then
                        if [ "$(cfg -g TZ_DIALTOOL2_NAT_AUX${apn_config:3} --section modem)" != "disable" ]; then
                                main_apn_nat=1
                        fi
                fi

                if [ $main_apn_nat -eq 1 ]; then
                        local wan=$main_apn_iface
                        local wan_ip=$(ifconfig $wan | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}')
                        if [ "${wan_ip}" != "" ]; then
                                iptables -w -t nat -I PREROUTING -i $wan -d $wan_ip -j DNAT --to-destination $host_ip
                                for i in $lan_iface; do
                                        iptables -w -t nat -I PREROUTING -i br-$i -d $wan_ip -j DNAT --to-destination $host_ip
                                done
                        fi
                fi

                # aux apn
                for x in $(echo 1 2 3); do
                        [ "$(cfg -g TZ_DIALTOOL${x}_NAT --section modem)" == "disable" ] && continue
                        apn_iface=$(uci get network.4g$x.ifname)
                        local wan=$apn_iface
                        local wan_ip=$(ifconfig $wan | grep "inet addr" | awk '{print $2}' | awk -F':' '{print $2}')
                        if [ "${wan_ip}" != "" ]; then
                                iptables -w -t nat -I PREROUTING -i $wan -d $wan_ip -j DNAT --to-destination $host_ip
                                for i in $lan_iface; do
                                        iptables -w -t nat -I PREROUTING -i br-$i -d $wan_ip -j DNAT --to-destination $host_ip
                                done
                        fi
                done
        }

        set_user_static_route() {
                local rows=$(cat /etc/config/tozed | grep TZ_STATIC_ROUTE | wc -l)
                local ip
                local netmask
                local network
                local table_name
                local i=1

                local table_num=10
                [ $(cat /etc/iproute2/rt_tables | grep "user_static_route" | wc -l) == "0" ] && {

                        while [ $(cat /etc/iproute2/rt_tables | grep "^$table_num       " | wc -l) != 0 ]; do
                                table_num=$(($table_num + 1))
                        done
                        echo "$table_num        user_static_route" >>/etc/iproute2/rt_tables
                }

                ip route flush table user_static_route

                while [ $i -le $rows ]; do
                        item=$(cat /etc/config/tozed | grep TZ_STATIC_ROUTE | sed -n ${i}p | sed s/\'//g)
                        let i=$i+1
                        local ifname=$(echo $item | awk '{print $3}')
                        local target_ip=$(echo $item | awk '{print $4}')
                        local target_netmask=$(echo $item | awk '{print $5}')
                        local next_ip=$(echo $item | awk '{print $6}')

                        local target_lan=$(ipcalc.sh $target_ip $target_netmask | grep -e PREFIX -e NETWORK | sed -e s/PREFIX=//g -e s/NETWORK=//g)
                        local target_prefix=$(echo ${target_lan} | awk '{print $2}')
                        target_ip=$(echo ${target_lan} | awk '{print $1}')

                        ip route add ${target_ip}/${target_prefix} table user_static_route via $next_ip dev $ifname

                done

        }

        block_modem_access() {
                local i
                for i in $(echo $main_apn_iface $aux_apn_iface); do
                        local gw_ip=$(ip r s default t if_$i | awk -F 'via' '{print $2}' | awk '{print $1}')
                        [ -z "$gw_ip" ] && continue
                        iptables -w -I FORWARD -d $gw_ip -j DROP
                        iptables -w -I FORWARD -d $gw_ip -p udp --dport 53 -j ACCEPT
                        iptables -w -I FORWARD -d $gw_ip -p icmp -j ACCEPT
                done
        }

        arp_bind() {

                #del arp
                local arp_list=$(arp -an | grep PERM | awk -F '[()]' '{print $2}')
                for var in $arp_list; do
                        arp -d $var
                done

                local TZ_ARP_LIST=$(cfg -g TZ_ARP_ITEM --section arp_bind)
                for var in $TZ_ARP_LIST; do
                        local en=${var:0:1}
                        local ip=${var%%-*}
                        local mac=${var#*-}
                        if [ $en == "#" ]; then
                                continue
                        fi
                        #       echo ip=$ip
                        #       echo mac=$mac
                        /sbin/arp -s $ip $mac
                done

        }

        lan_default_action() {
                for i in $(echo 1 2 3); do
                        if [ "$(uci get tozed.system.TZ_LAN${i}_ACTION)" != "0" ]; then
                                iptables -w -I FORWARD -i br-lan${i} -o eth0.2 -j DROP
                                iptables -w -I FORWARD -i br-lan${i} -o $main_apn_iface -j DROP
                        fi
                done
        }

        add_rule_tr069() {
                iptables -w -t filter -N drop_tr069
                iptables -w -t filter -D OUTPUT -j drop_tr069
                iptables -w -t filter -I OUTPUT -j drop_tr069
                if [ -e /tmp/.drop_tr069_ip ]; then
                        iptables -w -F drop_tr069
                        tr069_acs_ip=$(cat /tmp/.drop_tr069_ip | awk '{print $1}')
                        if [ "$tr069_acs_ip" != "" ]; then
                                for i in $wan_iface; do
                                        iptables -w -t filter -I drop_tr069 -d $tr069_acs_ip -o $i -j DROP
                                done
                        fi
                fi

                local tr069_listen_port=$(uci get tozed.cfg.tr069_ConnectionRequestPort)
                if [ "$tr069_listen_port" = "" ]; then
                        tr069_listen_port=5400
                fi

                #iptables -w -I INPUT -p tcp --dport $tr069_listen_port -j ACCEPT
                for i in $lan_iface; do
                        iptables -w -t filter -I INPUT -i br-$i -p tcp --dport $tr069_listen_port -j DROP
                done
        }

        add_rule_allow_voip_port() {

                listenport=$(cat /usr/system/srsip/setconfig | grep Listen_Port | awk -F = '{print $2}')
                if [ "$listenport" = "" ]; then
                        listenport=15060
                fi

                rtp_start=$(uci get tz_phone.nv.srsip_rtp_port_start)
                if [ "$rtp_start" = "" ]; then
                        rtp_start=60000
                fi

                rtp_end=$(uci get tz_phone.nv.srsip_rtp_port_end)
                if [ "$rtp_end" = "" ]; then
                        rtp_end=61000
                fi

                iptables -w -I INPUT -p tcp --dport $listenport -j ACCEPT
                iptables -w -I INPUT -p udp --dport $listenport -j ACCEPT

                iptables -w -I INPUT -p tcp --dport $rtp_start:$rtp_end -j ACCEPT
                iptables -w -I INPUT -p udp --dport $rtp_start:$rtp_end -j ACCEPT

        }

        add_rule_allow_l2tp_port() {
                l2tp_enable=$(uci get network.vpn2.auto)
                if [ "$l2tp_enable" = "1" ]; then
                        iptables -w -I INPUT -p udp -m udp --dport 1701 -j ACCEPT
                fi
        }
        add_rule_allow_sip_port() {
                local alg_enable=$(cfg -g sip_alg_enable --section system)
                if [ "${alg_enable}" = "1" ]; then
                        local alg_port=$(cfg -g sip_alg_port --section system)
                        iptables -w -t nat -A PREROUTING -i br-lan+ -p udp -m udp --dport $alg_port -j REDIRECT
                fi
        }
        add_rule_allow_ipsec_flow() {
                ipsec_enable=$(uci get ipsec.acme.enabled)
                if [ "$ipsec_enable" = "1" ]; then
                        iptables -w -I INPUT -m policy --dir in --pol ipsec --proto esp -j ACCEPT
                        iptables -w -I FORWARD -m policy --dir in --pol ipsec --proto esp -j ACCEPT
                        iptables -w -I FORWARD -m policy --dir out --pol ipsec --proto esp -j ACCEPT
                        iptables -w -I OUTPUT -m policy --dir out --pol ipsec --proto esp -j ACCEPT
                        . /etc/ipsec/firewall.sh
                fi
        }

        apply_url_dns_filter_rule() {
                link_status=$(cpeconfer modem_get_status | grep "network_link_stauts\s\+=\s\+1")
                cat $FIREWALL_FILTER_RULE_FILE | grep -w -E "$FIREWALL_URL_DNS_FILTER_PREX|$FIREWALL_URL_DNS_FILTER_FOR_WIFI_PREX" | while read ln; do
                        if [ "$link_status" == "" ]; then
                                continue
                        fi
                        url=$(echo $ln | awk -F'(' '{print $2}' | awk -F')' '{print $1}')
                        is_localhost=$(nslookup $url | grep -E "Address [[:digit:]]: 127.0.0.1|Address [[:digit:]]: ::1")
                        if [ "$is_localhost" == "" ]; then
                                ln=$(echo $ln | sed 's/^iptables /\1iptables -w /;s/^ip6tables /\1ip6tables -w /')
                                eval "$ln"
                        fi
                done
        }

        apply_all_filter() {
                if [ -e $FIREWALL_FILTER_RULE_FILE ]; then
                        for filter in $FIREWALL_FILTER_PREX_LIST; do
                                cat $FIREWALL_FILTER_RULE_FILE | grep "$filter" | while read ln; do
                                        ln=$(echo $ln | sed 's/^iptables /\1iptables -w /;s/^ip6tables /\1ip6tables -w /')
                                        eval "$ln"
                                        [ "$filter" == "MAC-FILTER" ] || [ "$filter" == "PORT-FILTER" ] && {
                                                eval "$(echo $ln | sed 's/^iptables/ip6tables/g')"
                                        }
                                done
                        done
                fi
        }

        init_upnp_rule() {
                local enable=$(uci get tozed.upnp.enable)
                if [ "$enable" == "1" ]; then
                        export TZ_WAN_LIST=$wan_iface
                        /etc/miniupnpd/iptables_init.sh >/dev/null
                fi
        }

        set_brctl_lan_wlan_wan() {
                local project=$(cat /version | grep type | cut -d= -f2)

                if [ "${project}" == "LT91" ]; then
                        local wan="eth0.2"
                        local wlan="ra0 ra1 ra2 rai0 rai1 rai2"
                        local lan="eth0.1 eth0.3 eth0.4 eth0.5"

                        for temp in $wan; do
                                for temp1 in $wlan; do
                                        ebtables -D FORWARD -i $temp -o $temp1 -j DROP
                                        ebtables -A FORWARD -i $temp -o $temp1 -j DROP
                                done

                                for temp2 in $lan; do
                                        ebtables -D FORWARD -i $temp -o $temp2 -j DROP
                                        ebtables -A FORWARD -i $temp -o $temp2 -j DROP
                                done
                        done

                        local dhcp=$(uci get dhcp.lan.ignore)
                        if [ "$dhcp" == "1" ]; then
                                for temp3 in $wlan; do
                                        for temp4 in $lan; do
                                                ebtables -D FORWARD -i $temp3 -o $temp4 -j DROP
                                                ebtables -A FORWARD -i $temp3 -o $temp4 -j DROP
                                        done
                                done
                        fi

                fi

        }

        setup_flow_statistics() {
                iptables -w -X forwarding_rule && iptables -w -N forwarding_rule
                iptables -w -D FORWARD -j forwarding_rule
                iptables -w -I FORWARD -j forwarding_rule
        }

        apply_advanced_all_filter() {
                # 支持一条规则多个IP(段)
                # 不直接跑firewall.user里的规则, 根据注释动态生成
                filter="ACL-ADVANCED-FILTER"
                if [ -e $FIREWALL_FILTER_RULE_FILE ]; then
                        cat $FIREWALL_FILTER_RULE_FILE | grep "$filter" | while read ln; do
                                echo "# ln[$ln]"
                                local adv_acl=
                                while true; do
                                        local idx=$(echo $ln | awk -F '##' '{print $8}')
                                        [ -z "$idx" ] && break
                                        [ "$idx" != "0" ] && adv_acl=1 && break
                                        local ip_block=$(echo $ln | awk -F '##' '{print $6}' | sed 's/,/ /g')
                                        local proto=$(echo $ln | awk -F 'tz_acl_' '{print $2}' | awk '{print $1}')
                                        local act=$(echo $ln | awk -F '##' '{print $5}')
                                        local zone=$(echo $ln | awk -F '##' '{print $3}')
                                        echo "# ip_block[$ip_block]"
                                        echo "# proto[$proto]"
                                        echo "# act[$act]"
                                        echo "# zone[$zone]"
                                        [ -z "$ip_block" ] && break
                                        [ -z "$proto" ] && break
                                        [ -z "$act" ] && break
                                        [ -z "$zone" ] && break
                                        local ip_addr
                                        local zone_iface='br-lan br-lan1 br-lan2 br-lan3'
                                        [ "$zone" == "wan" ] && zone_iface=$wan_iface
                                        echo "# zone_iface[$zone_iface]"
                                        for ip_addr in $ip_block; do
                                                echo "# ip_addr[$ip_addr]"
                                                local is_ip_range=
                                                [ "$(echo $ip_addr | grep -c '-')" != "0" ] && is_ip_range=1
                                                local iface
                                                for iface in $zone_iface; do
                                                        if [ "$is_ip_range" ]; then
                                                                iptables -w -A tz_acl_$proto -i $iface -m iprange --src-range "$ip_addr" -j $act
                                                        else
                                                                iptables -w -A tz_acl_$proto -i $iface -s "$ip_addr" -j $act
                                                        fi
                                                done
                                        done
                                        adv_acl=1
                                        break
                                done
                                if [ -z "$adv_acl" ]; then
                                        echo '# not adv acl, exec'
                                        eval "$ln"
                                fi
                                echo "# ----------------------------"
                        done
                fi
        }

        # 根据辅网桥开关配置项决定是否开启辅网桥允许访问WebUI
        allowed_to_access_web() {

                local ip=$(ifconfig br-lan | grep 'inet addr' | cut -d ':' -f2 | awk '{print $1}')

                local lan1_switch=$(uci get tozed.system.TZ_SYSTEM_LAN1_ACCESS_WEB_SWITCH)
                if [ "0" == "$lan1_switch" ]; then
                        iptables -w -I INPUT -i br-lan1 -p tcp -m multiport --destination-port 80,443 -j DROP
                fi

                local lan2_switch=$(uci get tozed.system.TZ_SYSTEM_LAN2_ACCESS_WEB_SWITCH)
                if [ "0" == "$lan2_switch" ]; then
                        iptables -w -I INPUT -i br-lan2 -p tcp -m multiport --destination-port 80,443 -j DROP
                fi

                local lan3_switch=$(uci get tozed.system.TZ_SYSTEM_LAN3_ACCESS_WEB_SWITCH)
                if [ "0" == "$lan3_switch" ]; then
                        iptables -w -I INPUT -i br-lan3 -p tcp -m multiport --destination-port 80,443 -j DROP
                fi

        }

        firewall_switch=$(uci get tozed.system.TZ_SYSTEM_FIREWALL_SWITCH)

        # redirect web port
        redirect_wan_blackhole

        if [ $TZ_REMOTE_LOGIN"" == "1" ]; then
                turn_on_remote_web_login
        else
                turn_off_remote_web_login
        fi

        if [ $TZ_REMOTE_PING"" == "1" ]; then
                turn_on_remote_ping
        else
                turn_off_remote_ping
        fi

        if [ "$firewall_switch" != "0" ]; then
                apply_advanced_all_filter
        fi

        set_user_static_route

        #set nat rule
        set_nat_mode_rule

        #for tr069
        add_rule_tr069

        #for tzphone voip
        add_rule_allow_voip_port

        #for xl2tpd flow
        add_rule_allow_l2tp_port

        #for ipsec flow
        add_rule_allow_ipsec_flow

        #for sip flow
        add_rule_allow_sip_port

        if [ "$firewall_switch" != "0" ]; then
                arp_bind
        fi

        lan_default_action

        if [ "$firewall_switch" != "0" ]; then

                DDOS_ENABLE=$(uci get tozed.system.FIREWALL_DDOS_ENABLE)
                if [ "${DDOS_ENABLE}" != "0" ]; then
                        defense_attack
                fi

                if [ $TZ_DMZ_ENABLE"" == "1" ]; then
                        set_dmz
                fi

                #apply all filter
                apply_all_filter

                redirect_wan
                init_upnp_rule
        fi

        #for LT91 break lan  wan and wlan
        set_brctl_lan_wlan_wan

        block_modem_access

        export wan_iface

        for fw_script in $(ls $post_script); do
                $post_script/$fw_script
        done

        # iptables -w -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        # iptables -w -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        # iptables -w -I OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        # ip6tables -w -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        # ip6tables -w -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        # ip6tables -w -I OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

        setup_flow_statistics

        if [ "$firewall_switch" != "0" ]; then
                apply_url_dns_filter_rule
        fi

        allowed_to_access_web

        /sbin/dnsfwd.sh

        [ "$(uci get network.vpn1.auto)" == "1" ] && iptables -w -t nat -I PREROUTING -p gre -j ACCEPT

        rm -rf $lock_file
) >$ipt_log 2>&1
