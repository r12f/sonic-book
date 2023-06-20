# 安装

如果你自己就拥有一台交换机，或者想购买一台交换机，在上面安装SONiC，那么请认真阅读这一小节，否则可以自行跳过。:D

## 交换机选择和SONiC安装

首先，请确认你的交换机是否支持SONiC，SONiC目前支持的交换机型号可以在[这里][SONiCDevices]找到，如果你的交换机型号不在列表中，那么就需要联系厂商，看看是否有支持SONiC的计划。有很多交换机是不支持SONiC的，比如：

1. 普通针对家用的交换机，这些交换机的硬件配置都比较低（即便支持的带宽很高，比如[MikroTik CRS504-4XQ-IN][MikroTik100G]，虽然它支持100GbE网络，但是它只有16MB的Flash存储和64MB的RAM，所以基本只能跑它自己的RouterOS了）。
2. 有些虽然是数据中心用的交换机，但是可能由于型号老旧，厂商并没有计划支持SONiC。

对于安装过程，由于每一家厂商的交换机设计不同，其底层接口各有差别，所以，其安装方法也都有所差别，这些差别主要集中在两个地方：

1. 每个厂商都会有自己的[SONiC Build][SONiCDevices]，还有的厂商会在SONiC的基础之上进行扩展开发，为自己的交换机支持更多的功能，比如：[Dell Enterprise SONiC][DellSonic]，[EdgeCore Enterprise SONiC][EdgeCoreSONiC]，所以需要根据自己的交换机选择对应的版本。
2. 每个厂商的交换机也会支持不同的安装方式，有一些是直接使用USB对ROM进行Flash，有一些是通过ONIE进行安装，这也需要根据自己的交换机来进行配置。

所以，虽然安装方法各有差别，但是总体而言，安装的步骤都是差不多的。请联系自己的厂商，获取对应的安装文档，然后按照文档进行安装即可。

## 配置交换机

安装好之后，我们需要进行一些基础设置，部分设置是通用的，我们在这里简单总结一下。

### 设置admin密码

默认SONiC的账号密码是admin:YourPaSsWoRd，使用默认密码显然不安全：

```bash
sudo passwd admin
```

### 设置风扇转速

数据中心用的交换机风扇声音都特别的大！比如，我用的交换机是Arista 7050QX-32S，上面有4个风扇，最高能到每分钟17000转，放在车库中，高频的啸叫即便是在二楼隔着3面墙还是能听得到，所以如果你是在家使用的话，建议对其进行一些设置，将转速调低。

可惜，[由于SONiC并没有cli对风扇转速的规则进行控制][SONiCThermal]，所以我们需要通过手动修改pmon容器中的配置文件的方式来进行设置。

```bash
# Enter pmon container
sudo docker exec -it pmon bash

# Use pwmconfig to detect all pwm fans and create configuration file. The configuration file will be created at /etc/fancontrol.
pwmconfig

# Start fancontrol and make sure it works. If it doesn't work, you can run fancontrol directly to see what's wrong.
VERBOSE=1 /etc/init.d/fancontrol start
VERBOSE=1 /etc/init.d/fancontrol status

# Exit pmon container
exit

# Copy the configuration file from the container to the host, so that the configuration will not be lost after reboot.
# This command needs to know what is the model of your switch, for example, the command I need to run here is as follows. If your switch model is different, please modify it yourself.
sudo docker cp pmon:/etc/fancontrol /usr/share/sonic/device/x86_64-arista_7050_qx32s/fancontrol
```

### 设置交换机Management Port IP

一般的数据中心用的交换机都提供了Serial Console连接的方式，但是其速度实在是太慢了，所以我们在安装完成之后，都会尽快的把Management Port给设置好，然后通过SSH的方式来进行管理。

一般来说，management port的设备名是eth0，所以我们可以通过SONiC的配置命令来进行设置：

```bash
# sudo config interface ip add eth0 <ip-cidr> <gateway>
# IPv4
sudo config interface ip add eth0 192.168.1.2/24 192.168.1.1

# IPv6
sudo config interface ip add eth0 2001::8/64 2001::1
```

### 创建网络配置

新安装完的SONiC交换机会有一个默认的网络配置，这个配置有很多问题，比如对于10.0.0.0的IP的使用，如下：

```bash
admin@sonic:~$ show ip interfaces
Interface    Master    IPv4 address/mask    Admin/Oper    BGP Neighbor    Neighbor IP
-----------  --------  -------------------  ------------  --------------  -------------
Ethernet0              10.0.0.0/31          up/up         ARISTA01T2      10.0.0.1
Ethernet4              10.0.0.2/31          up/up         ARISTA02T2      10.0.0.3
Ethernet8              10.0.0.4/31          up/up         ARISTA03T2      10.0.0.5
```

所以我们需要创建一个新的网络配置，然后将我们使用的Port都放入到这个网络配置中。这里简单的方法就是创建一个VLAN，使用VLAN Routing：

```bash
# Create untagged vlan
sudo config vlan add 2

# Add IP to vlan
sudo config interface ip add Vlan2 10.2.0.0/24

# Remove all default IP settings
show ip interfaces | tail -n +3 | grep Ethernet | awk '{print "sudo config interface ip remove", $1, $2}' > oobe.sh; chmod +x oobe.sh; ./oobe.sh

# Add all ports to the new vlan
show interfaces status | tail -n +3 | grep Ethernet | awk '{print "sudo config vlan member add -u 2", $1}' > oobe.sh; chmod +x oobe.sh; ./oobe.sh

# Enable proxy arp, so switch can respond to arp requests from hosts
sudo config vlan proxy_arp 2 enabled

# Save config, so it will be persistent after reboot
sudo config save -y
```

这样就完成了，我们可以通过show vlan brief来查看一下：

```
admin@sonic:~$ show vlan brief
+-----------+--------------+-------------+----------------+-------------+-----------------------+
|   VLAN ID | IP Address   | Ports       | Port Tagging   | Proxy ARP   | DHCP Helper Address   |
+===========+==============+=============+================+=============+=======================+
|         2 | 10.2.0.0/24  | Ethernet0   | untagged       | enabled     |                       |
...
|           |              | Ethernet124 | untagged       |             |                       |
+-----------+--------------+-------------+----------------+-------------+-----------------------+
```

### 配置主机

如果你家里只有一台主机使用多网口连接交换机进行测试，那么我们还需要在主机上进行一些配置，以保证流量会通过网卡，流经交换机，否则，请跳过这一步。

这里网上的攻略很多，比如使用iptables中的DNAT和SNAT创建一个虚拟地址，但是过程非常繁琐，经过一些实验，我发现最简单的办法就是将其中一个网口移动到一个新的网络命名空间中，就可以了，即便使用的是同一个网段的IP，也不会有问题。

比如，我家使用的是Netronome Agilio CX 2x40GbE，它会创建两个interface：`enp66s0np0`和`enp66s0np1`，我们这里可以将`enp66s0np1`移动到一个新的网络命名空间中，再配置好ip地址就可以了：

```bash
# Create a new network namespace
sudo ip netns add toy-ns-1

# Move the interface to the new namespace
sudo ip link set enp66s0np1 netns toy-ns-1

# Setting up IP and default routes
sudo ip netns exec toy-ns-1 ip addr add 10.2.0.11/24 dev enp66s0np1
sudo ip netns exec toy-ns-1 ip link set enp66s0np1 up
sudo ip netns exec toy-ns-1 ip route add default via 10.2.0.1
```

这样就可以了，我们可以通过iperf来测试一下，并在交换机上进行确认：

```bash
# On the host (enp66s0np0 has ip 10.2.0.10 assigned)
$ iperf -s --bind 10.2.0.10

# Test within the new network namespace
$ sudo ip netns exec toy-ns-1 iperf -c 10.2.0.10 -i 1 -P 16
------------------------------------------------------------
Client connecting to 10.2.0.10, TCP port 5001
TCP window size: 85.0 KByte (default)
------------------------------------------------------------
...
[SUM] 0.0000-10.0301 sec  30.7 GBytes  26.3 Gbits/sec
[ CT] final connect times (min/avg/max/stdev) = 0.288/0.465/0.647/0.095 ms (tot/err) = 16/0

# Confirm on switch
admin@sonic:~$ show interfaces counters
      IFACE    STATE       RX_OK        RX_BPS    RX_UTIL    RX_ERR    RX_DRP    RX_OVR       TX_OK        TX_BPS    TX_UTIL    TX_ERR    TX_DRP    TX_OVR
-----------  -------  ----------  ------------  ---------  --------  --------  --------  ----------  ------------  ---------  --------  --------  --------
  Ethernet4        U   2,580,140  6190.34 KB/s      0.12%         0     3,783         0  51,263,535  2086.64 MB/s     41.73%         0         0         0
 Ethernet12        U  51,261,888  2086.79 MB/s     41.74%         0         1         0   2,580,317  6191.00 KB/s      0.12%         0         0         0
```

# 参考资料

1. [SONiC Supported Devices and Platforms][SONiCDevices]
2. [SONiC Thermal Control Design][SONiCThermal]
3. [Dell Enterprise SONiC Distribution][DellSONiC]
4. [Edgecore Enterprise SONiC  Distribution][EdgeCoreSONiC]
5. [Mikrotik CRS504-4XQ-IN][MikroTik100G]

[SONiCDevices]: https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html
[DellSONiC]: https://www.dell.com/en-us/shop/povw/sonic
[EdgeCoreSONiC]: https://www.edge-core.com/sonic.php
[MikroTik100G]: https://mikrotik.com/product/crs504_4xq_in
[SONiCThermal]: https://github.com/sonic-net/SONiC/blob/master/thermal-control-design.md