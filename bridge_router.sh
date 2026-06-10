#!/bin/sh

BACKUP_DIR="/root"

show_status() {
    LAN_IP=$(uci -q get network.lan.ipaddr)
    GATEWAY=$(uci -q get network.lan.gateway)
    DNS=$(uci -q get network.lan.dns | head -n1)

    DHCP=$(uci -q get dhcp.lan.ignore)

    [ "$DHCP" = "1" ] && DHCP_STATUS="已关闭" || DHCP_STATUS="已开启"

    echo
    echo "当前配置"
    echo "--------------------------------"
    echo "LAN IP : ${LAN_IP:-未设置}"
    echo "网关   : ${GATEWAY:-未设置}"
    echo "DNS    : ${DNS:-未设置}"
    echo "DHCP   : ${DHCP_STATUS}"
    echo "--------------------------------"
    echo
}

backup_config() {

    BACKUP_FILE="$BACKUP_DIR/network_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

    tar czf "$BACKUP_FILE" \
        /etc/config/network \
        /etc/config/dhcp \
        /etc/config/firewall \
        >/dev/null 2>&1

    echo
    echo "配置已备份:"
    echo "$BACKUP_FILE"
    echo

}

apply_bypass() {

    backup_config

    echo
    read -p "旁路由IP [192.168.123.10]: " IPADDR
    IPADDR=${IPADDR:-192.168.123.10}

    read -p "子网掩码 [255.255.255.0]: " NETMASK
    NETMASK=${NETMASK:-255.255.255.0}

    read -p "主路由网关 [192.168.123.1]: " GATEWAY
    GATEWAY=${GATEWAY:-192.168.123.1}

    read -p "DNS服务器 [192.168.123.1]: " DNS
    DNS=${DNS:-192.168.123.1}

    echo
    echo "DHCP服务"
    echo "1. 开启"
    echo "2. 关闭(推荐)"
    read -p "请选择 [2]: " DHCPMODE
    DHCPMODE=${DHCPMODE:-2}

    echo
    echo "NAT功能"
    echo "1. 开启"
    echo "2. 关闭"
    read -p "请选择 [1]: " NATMODE
    NATMODE=${NATMODE:-1}

    echo
    echo "配置如下"
    echo "--------------------------------"
    echo "IP      : $IPADDR"
    echo "MASK    : $NETMASK"
    echo "GATEWAY : $GATEWAY"
    echo "DNS     : $DNS"

    [ "$DHCPMODE" = "1" ] && echo "DHCP    : 开启" || echo "DHCP    : 关闭"
    [ "$NATMODE" = "1" ] && echo "NAT     : 开启" || echo "NAT     : 关闭"

    echo "--------------------------------"

    echo
    read -p "确认应用? [Y/n] " CONFIRM

    case "$CONFIRM" in
        n|N)
            echo "已取消"
            return
        ;;
    esac

    uci set network.lan.proto='static'
    uci set network.lan.ipaddr="$IPADDR"
    uci set network.lan.netmask="$NETMASK"
    uci set network.lan.gateway="$GATEWAY"

    uci delete network.lan.dns 2>/dev/null
    uci add_list network.lan.dns="$DNS"

    if [ "$DHCPMODE" = "1" ]; then
        uci set dhcp.lan.ignore='0'
    else
        uci set dhcp.lan.ignore='1'
    fi

    uci commit network
    uci commit dhcp

    if [ "$NATMODE" = "1" ]; then

        uci -q delete firewall.bypass_nat

        uci set firewall.bypass_nat="zone"
        uci set firewall.bypass_nat.name="bypass_nat"
        uci set firewall.bypass_nat.network="lan"
        uci set firewall.bypass_nat.input="ACCEPT"
        uci set firewall.bypass_nat.output="ACCEPT"
        uci set firewall.bypass_nat.forward="ACCEPT"
        uci set firewall.bypass_nat.masq="1"

        uci commit firewall

    fi

    echo
    echo "正在重启网络..."

    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    /etc/init.d/firewall restart

    echo
    echo "配置完成"
    echo
    echo "新的管理地址:"
    echo "http://$IPADDR"
    echo
}

restore_latest() {

    LATEST=$(ls -t $BACKUP_DIR/network_backup_*.tar.gz 2>/dev/null | head -n1)

    if [ -z "$LATEST" ]; then
        echo
        echo "未找到备份"
        echo
        return
    fi

    echo
    echo "恢复备份:"
    echo "$LATEST"
    echo

    read -p "确认恢复? [Y/n] " CONFIRM

    case "$CONFIRM" in
        n|N)
            return
        ;;
    esac

    cd /

    tar -xzf "$LATEST"

    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    /etc/init.d/firewall restart

    echo
    echo "恢复完成"
    echo
}

list_backup() {

    echo

    FILES=$(ls -t $BACKUP_DIR/network_backup_*.tar.gz 2>/dev/null)

    if [ -z "$FILES" ]; then
        echo "暂无备份"
        echo
        return
    fi

    COUNT=1

    for FILE in $FILES
    do
        echo "$COUNT) $(basename "$FILE")"
        COUNT=$((COUNT+1))
    done

    echo
    read -p "输入编号恢复(直接回车返回): " NUM

    [ -z "$NUM" ] && return

    FILE=$(echo "$FILES" | sed -n "${NUM}p")

    [ -z "$FILE" ] && return

    echo
    echo "恢复:"
    echo "$FILE"

    read -p "确认恢复? [Y/n] " CONFIRM

    case "$CONFIRM" in
        n|N)
            return
        ;;
    esac

    cd /

    tar -xzf "$FILE"

    /etc/init.d/network restart
    /etc/init.d/dnsmasq restart
    /etc/init.d/firewall restart

    echo
    echo "恢复完成"
    echo
}

while true
do
    clear

    echo "================================"
    echo " OpenWrt 旁路由向导"
    echo "================================"

    show_status

    echo "1. 一键配置旁路由"
    echo "2. 恢复最近备份"
    echo "3. 查看备份列表"
    echo "4. 查看当前状态"
    echo "5. 退出"
    echo

    read -p "请选择: " CHOICE

    case "$CHOICE" in

        1)
            apply_bypass
            read -p "按回车继续..."
        ;;

        2)
            restore_latest
            read -p "按回车继续..."
        ;;

        3)
            list_backup
            read -p "按回车继续..."
        ;;

        4)
            show_status
            read -p "按回车继续..."
        ;;

        5)
            exit 0
        ;;

    esac

done
