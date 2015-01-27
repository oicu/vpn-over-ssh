# vpn-over-ssh
Poor mans VPN over SSH, script which can help to setup VPN based on **OpenSSH version 4.3+**, creates a ssh tunnel to **connect two networks, require root, works with Linux**.

# Prerequisites

## Server & Client
CentOS:  
`yum install tunctl`

Debian/Ubuntu:  
`sudo apt-get install uml-utilities`  

`which ip iptables`  
The script also need the '**ip**' command (from the 'iproute' package) and '**iptables**' command (from the 'iptables' package), install them in both the local and remote computers.

## Server

`vim /etc/ssh/sshd_config`
>     PermitRootLogin yes  
>     PermitTunnel yes  
>     ClientAliveInterval 30  
>     ClientAliveCountMax 6

CentOS:  
`/etc/init.d/sshd restart`

Debian/Ubuntu:  
`sudo /etc/init.d/ssh restart`

## Client (not required)
`vim /etc/ssh/ssh_config`
>     ServerAliveInterval 30  
>     ServerAliveCountMax 6

# Usage
Edit **svpn.sh**, just run it on client.

>     SERVER_SSH_PORT="22"  
>     SERVER_SSH_IP="1.2.3.4"  
>     CLIENT_ETHERNET="eth0"  
>     SERVER_ETHERNET="eth0"  
>     CLIENT_TUNNEL="tun2"  
>     SERVER_TUNNEL="tun1"  
>     CLIENT_TUN_IP="10.0.0.2"  
>     SERVER_TUN_IP="10.0.0.1"  
>     CLIENT_NET="192.168.2.0/24"  
>     CLIENT_GATEWAY="192.168.2.1"  
>     SERVER_NET="192.168.1.0/24"  
>     SERVER_GATEWAY="192.168.1.1"

## Start VPN
`svpn.sh -start`

## Stop VPN
`svpn.sh -stop`

# Network topology

* Server: Machine A/Host A  
* Client: Machine B/Host B

## Network topology A (Default)
>                    Has internet     Has internet  
>     192.168.1.0/24 (netA)|gateA <-> gateB|192.168.2.0/24 (netB)  
>
>     +------------------+            OpenSSH 4.3            +-----------------+  
>     |   Machine A      | tun1 -- Tunnel Interface -- tun2  |    Machine B    |  
>     |  Has a tunnel    | <-------------------------------->|   Has a tunnel  |  
>     |  and ethernet    | 10.0.0.1                10.0.0.2  |   and ethernet  |  
>     +----------+-------+     point to point connection     +---------+-------+  
>                | eth0                                           eth0 |  
>                | 192.168.1.100                         192.168.2.100 |  
>                | port 22                                             |  
>                | forwarded                                           |  
>                | here                                                |  
>     +----------+----------+          +-~-~-~-~-~-~-~-+       +-------+-------+  
>     |     Network A       |          |               |       |   Network B   |  
>     |    192.168.1.0/24   | 1.2.3.4  |  The Internet |       | 192.168.2.0/24|  
>     |    Has internet     |<-------->|               |<----->|  Has internet |  
>     |    NAT gateway      | Routable |               |       |  NAT gateway  |  
>     +---------------------+ Address  +-~-~-~-~-~-~-~-+       +---------------+  

## Network topology B
>            hostA hasn't internet     Has internet  
>     192.168.1.0/24  (netA)|gateA <-- hostB|1.2.3.4  
>
>     +------------------+            OpenSSH 4.3            +-----------------+  
>     |   Machine A      | tun1 -- Tunnel Interface -- tun2  |    Machine B    |  
>     |  Has a tunnel    | <-------------------------------->|   Has a tunnel  |  
>     |  and ethernet    | 10.0.0.1                10.0.0.2  |   and ethernet  |  
>     +----------+-------+     point to point connection     +---------+-------+  
>                | eth0                                           eth0 |  
>                | 192.168.1.100                               1.2.3.4 |  
>                | port 22                                Has internet |  
>                | forwarded                                           |  
>                | here                                                |  
>     +----------+----------+          +-~-~-~-~-~-~-~-+               |  
>     |     Network A       |          |               |               |  
>     |    192.168.1.0/24   | 4.3.2.1  |  The Internet |               |  
>     |  Hasn't internet    |<-------->|               |<--------------+  
>     |    NAT gateway      | Routable |               |  
>     +---------------------+ Address  +-~-~-~-~-~-~-~-+

Edit **svpn.sh**

>     36:    ip route replace default via ${SERVER_GATEWAY}  
>     37:    # ip route del ${CLIENT_NET} via ${SERVER_TUN_IP}  
>     47:    # ip route add ${CLIENT_NET} via ${SERVER_TUN_IP}  
>     48:    ip route replace default via ${SERVER_TUN_IP}  
>     77:    ip route replace default via ${SERVER_GATEWAY}  
>     78:    # ip route del ${CLIENT_NET} via ${SERVER_TUN_IP}

## Network topology C
>                    Has internet     Has internet  
>     192.168.2.0/24 (netB)|gateB --> hostA|1.2.3.4 --> GFW  
>     or  
>                   4.3.2.1|hostB --> hostA|1.2.3.4 --> GFW  
>
>     +------------------+            OpenSSH 4.3            +-----------------+  
>     |   Machine B      | tun2 -- Tunnel Interface -- tun1  |    Machine A    |  
>     |  Has a tunnel    | <-------------------------------->|   Has a tunnel  |  
>     |  and ethernet    | 10.0.0.2                10.0.0.1  |   and ethernet  |  
>     +----------+-------+     point to point connection     +---------+-------+  
>                |                                                     ^  
>                |                                                eth0 |  
>                |                                             1.2.3.4 |  
>                |                                        Has internet |  
>                |                                                     |  
>     +----------+----------+          +-~-~-~-~-~-~-~-+               |  
>     |     Network B       |          |               |               |  
>     |    192.168.2.0/24   | 4.3.2.1  |  The Internet |               |  
>     |    Has internet     |<-------->|               |---------------+  
>     |    NAT gateway      | Routable |               |  
>     +---------------------+ Address  +-~-~-~-~-~-~-~-+

Edit **svpn.sh**

>     62:    # ip route add ${SERVER_NET} via ${CLIENT_TUN_IP}  
>     63:    ip route replace default via ${CLIENT_TUN_IP}  
>     64:    # iptables -t nat -A POSTROUTING -s ${SERVER_TUN_IP}/32 -o ${CLIENT_ETHERNET} -j MASQUERADE  
>     65:    # iptables -A FORWARD -p tcp --syn -s ${SERVER_TUN_IP}/32 -j TCPMSS --set-mss 1356  
>     90:    ip route replace default via ${CLIENT_GATEWAY}  
>     91:    # ip route del ${SERVER_NET} via ${CLIENT_TUN_IP}  
>     93:    # iptables -t nat -D POSTROUTING -s ${SERVER_TUN_IP}/32 -o ${CLIENT_ETHERNET} -j MASQUERADE  
>     94:    # iptables -D FORWARD -p tcp --syn -s ${SERVER_TUN_IP}/32 -j TCPMSS --set-mss 1356

# Performance (ping test)
## Topology B
Installing VMware Workstation 11 on Machine A (Windows 7).
>                              +-~-~-~-+-~-~-~-+  
>                              | Gateway G     |  
>                              | 192.168.1.1   |  
>                              +-~-~-~-+-~-~-~-+  
>                                      |  
>             +------------------------+------------------------+  
>             |                        |                        |  
>     +-------+-------+        +-------+-------+        +-------+-------+  
>     | Machine A     |        | Machine B     |        | Machine C     |  
>     | 192.168.1.4   |        | 192.168.1.2   |        | 192.168.1.3   |  
>     +-------+-------+        +---------------+        +---------------+  
>             |  
>             +------------------------+------------------------+  
>             |                        |                        |  
>             |                +-~-~-~-+-~-~-~-+        +-~-~-~-+-~-~-~-+  
>             |                |      NAT      |        |   Host-only   |  
>             |                |   Gateway E   |        |   Gateway F   |  
>             |                |  192.168.72.1 |        |  192.168.19.1 |  
>             |                +-~-~-~-+-~-~-~-+        +-~-~-~-+-~-~-~-+  
>             | Bridge                 |                        |  
>     +-------+-------+        +-------+-------+        +-------+-------+  
>     | VM Machine D1 |        | VM Machine D2 |        | VM Machine D3 |  
>     | 192.168.1.5   |        | 192.168.72.2  |        | 192.168.19.2  |  
>     +---------------+        +---------------+        +---------------+  

### Host-only
>     Machine B --> ssh --> Machine A --> port forwarded --> VM Machine D3  
>          ^                                                       ^  
>     tun2 |    SSH Tunnel Interface, point to point connection    | tun1  
>          +-------------------------------------------------------+  
> 
>     D3 -> D3         ping -c 50 192.168.19.2         0.074 ms  
>     D3 -> F          ping -c 50 192.168.19.1         0.414 ms  
>     D3 -> A          ping -c 50 192.168.1.4          3.636 ms  
>     D3 -> G          ping -c 50 192.168.1.1          2.514 ms  
>     D3 -> B          ping -c 50 192.168.1.2          2.488 ms  
>     D3 -> C          ping -c 50 192.168.1.3          2.522 ms  

### Bridge
>     D1 -> D1         ping -c 50 192.168.1.5          0.074 ms  
>     D1 -> A          ping -c 50 192.168.1.4          0.452 ms  
>     D1 -> G          ping -c 50 192.168.1.1          1.421 ms  
>     D1 -> B          ping -c 50 192.168.1.2          1.361 ms  
>     D1 -> C          ping -c 50 192.168.1.3          1.429 ms  

### NAT
>     D2 -> D2         ping -c 50 192.168.72.2         0.074 ms  
>     D2 -> E          ping -c 50 192.168.72.1         0.411 ms  
>     D2 -> F          ping -c 50 192.168.19.1         1.127 ms  
>     D2 -> A          ping -c 50 192.168.1.4          1.155 ms  
>     D2 -> G          ping -c 50 192.168.1.1          1.996 ms  
>     D2 -> B          ping -c 50 192.168.1.2          1.997 ms  
>     D2 -> C          ping -c 50 192.168.1.3          1.931 ms  
