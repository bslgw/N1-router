#!/bin/sh
# 一键透明拦截 53，所有 LAN 客户端 DNS 走本地 dnsmasq/ mosdns
# 使用方法:
#   ./dns_redirect.sh start   # 开启透明代理
#   ./dns_redirect.sh stop    # 撤销规则

LOCAL_DNS_PORT=53   # dnsmasq 监听端口
MOSDNS_PORT=5335    # mosdns 上游端口
LAN_IF="br-lan"    # LAN 接口名称，视你的 N1 设置修改

start() {
    echo "[*] 开启透明 DNS 代理 ..."
    # UDP
    iptables -t nat -A PREROUTING -i $LAN_IF -p udp --dport 53 -j REDIRECT --to-ports $LOCAL_DNS_PORT
    # TCP
    iptables -t nat -A PREROUTING -i $LAN_IF -p tcp --dport 53 -j REDIRECT --to-ports $LOCAL_DNS_PORT
    echo "[*] 完成。所有 LAN 客户端 53 请求已重定向到本机 dnsmasq:$LOCAL_DNS_PORT"
}

stop() {
    echo "[*] 撤销透明 DNS 代理 ..."
    # UDP
    iptables -t nat -D PREROUTING -i $LAN_IF -p udp --dport 53 -j REDIRECT --to-ports $LOCAL_DNS_PORT
    # TCP
    iptables -t nat -D PREROUTING -i $LAN_IF -p tcp --dport 53 -j REDIRECT --to-ports $LOCAL_DNS_PORT
    echo "[*] 完成。规则已撤销。"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    *)
        echo "用法: $0 {start|stop}"
        exit 1
        ;;
esac