#!/bin/bash
#########################################
#FileName:    svpn.sh
#Author:      oicu
#Blog:        http://oicu.cc.blog.163.com/
#########################################
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin
export PATH

[ "$(whoami)" != 'root' ] && echo "Run it as root." && exit 1

SERVER_SSH_PORT="22"
SERVER_SSH_IP="1.2.3.4"
CLIENT_ETHERNET="eth0"
SERVER_ETHERNET="eth0"
CLIENT_TUNNEL="tun2"
SERVER_TUNNEL="tun1"
CLIENT_TUN_IP="10.0.0.2"
SERVER_TUN_IP="10.0.0.1"
CLIENT_NET="192.168.2.0/24"
CLIENT_GATEWAY="192.168.2.1"
SERVER_NET="192.168.1.0/24"
SERVER_GATEWAY="192.168.1.1"

start()
{
ssh -NTCf -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=6 \
        -o ExitOnForwardFailure=yes \
        -o Tunnel=point-to-point \
        -w "${CLIENT_TUNNEL#tun}:${SERVER_TUNNEL#tun}" \
        root@${SERVER_SSH_IP} -p ${SERVER_SSH_PORT}
echo "ssh tunnel is working."
ssh -T root@${SERVER_SSH_IP} -p ${SERVER_SSH_PORT} > /dev/null 2>&1 << eeooff
            # ip route replace default via ${SERVER_GATEWAY}
            ip route del ${CLIENT_NET} via ${SERVER_TUN_IP}
            ip link set ${SERVER_TUNNEL} down
            iptables -t nat -D POSTROUTING -s ${CLIENT_TUN_IP}/32 -o ${SERVER_ETHERNET} -j MASQUERADE
            iptables -D FORWARD -p tcp --syn -s ${CLIENT_TUN_IP}/32 -j TCPMSS --set-mss 1356
            iptables -t nat -D POSTROUTING -s ${SERVER_NET} -o ${SERVER_TUNNEL} -j MASQUERADE

            ifconfig ${SERVER_TUNNEL} > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo 1 > /proc/sys/net/ipv4/ip_forward
                ip link set ${SERVER_TUNNEL} up
                ip addr add ${SERVER_TUN_IP}/32 peer ${CLIENT_TUN_IP} dev ${SERVER_TUNNEL}
                ip route add ${CLIENT_NET} via ${SERVER_TUN_IP}
                # ip route replace default via ${SERVER_TUN_IP}
                iptables -t nat -A POSTROUTING -s ${CLIENT_TUN_IP}/32 -o ${SERVER_ETHERNET} -j MASQUERADE
                iptables -A FORWARD -p tcp --syn -s ${CLIENT_TUN_IP}/32 -j TCPMSS --set-mss 1356
                iptables -t nat -A POSTROUTING -s ${SERVER_NET} -o ${SERVER_TUNNEL} -j MASQUERADE
            else
                exit 1
            fi
            exit
eeooff
echo "remote start."
sleep 3
ifconfig ${CLIENT_TUNNEL} > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo 1 > /proc/sys/net/ipv4/ip_forward
    ip link set ${CLIENT_TUNNEL} up
    ip addr add ${CLIENT_TUN_IP}/32 peer ${SERVER_TUN_IP} dev ${CLIENT_TUNNEL}
    ip route add ${SERVER_NET} via ${CLIENT_TUN_IP}
    # ip route replace default via ${CLIENT_TUN_IP}
    iptables -t nat -A POSTROUTING -s ${SERVER_TUN_IP}/32 -o ${CLIENT_ETHERNET} -j MASQUERADE
    iptables -A FORWARD -p tcp --syn -s ${SERVER_TUN_IP}/32 -j TCPMSS --set-mss 1356
    iptables -t nat -A POSTROUTING -s ${CLIENT_NET} -o ${CLIENT_TUNNEL} -j MASQUERADE
    ping ${SERVER_TUN_IP} -i 60 > /dev/null 2>&1 &
else
    exit 1
fi
echo "local start."
}

stop-srv()
{
ssh -T root@${SERVER_SSH_IP} -p ${SERVER_SSH_PORT} > /dev/null 2>&1 << eeooff
    # ip route replace default via ${SERVER_GATEWAY}
    ip route del ${CLIENT_NET} via ${SERVER_TUN_IP}
    ip link set ${SERVER_TUNNEL} down
    iptables -t nat -D POSTROUTING -s ${CLIENT_TUN_IP}/32 -o ${SERVER_ETHERNET} -j MASQUERADE
    iptables -D FORWARD -p tcp --syn -s ${CLIENT_TUN_IP}/32 -j TCPMSS --set-mss 1356
    iptables -t nat -D POSTROUTING -s ${SERVER_NET} -o ${SERVER_TUNNEL} -j MASQUERADE
    exit
eeooff
echo "remote stop."
}

stop()
{
# ip route replace default via ${CLIENT_GATEWAY}
ip route del ${SERVER_NET} via ${CLIENT_TUN_IP}
ip link set ${CLIENT_TUNNEL} down
iptables -t nat -D POSTROUTING -s ${SERVER_TUN_IP}/32 -o ${CLIENT_ETHERNET} -j MASQUERADE
iptables -D FORWARD -p tcp --syn -s ${SERVER_TUN_IP}/32 -j TCPMSS --set-mss 1356
iptables -t nat -D POSTROUTING -s ${CLIENT_NET} -o ${CLIENT_TUNNEL} -j MASQUERADE
CLIENT_SSH_PID=`ps -ef | grep 'ssh -NTCf -o' | grep -v grep | head -n1 | awk '{print $2}'`
if [ -n "${CLIENT_SSH_PID}" ]; then kill -9 ${CLIENT_SSH_PID}; fi
if [ -n "`pidof ping`" ]; then pidof ping | xargs kill -9; fi
} > /dev/null 2>&1

usage()
{
echo "usage:"
echo "    $0 -start"
echo "    $0 -stop"
echo ""
echo "for ssh:"
echo "    nohup $0 -start > /dev/null 2>&1"
}

case $1 in
    "--start" | "-start")
        stop
        start
        ;;
    "--stop" | "-stop")
        stop-srv
        stop
        echo "local stop."
        ;;
    *)
        usage
        ;;
esac
