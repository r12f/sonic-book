# Installation

如果你自己就拥有一台交换机，或者想购买一台交换机，在上面安装SONiC，那么请认真阅读这一小节，否则可以自行跳过。:D

## Switch Selection and SONiC Installation

First, please confirm if your switch supports SONiC. The list of currently supported switch models can be found [here][SONiCDevices]. If your switch model is not on the list, you will need to contact the manufacturer to see if they have plans to support SONiC. There are many switches that do not support SONiC, such as:

1. Regular switches for home use. These switches have relatively low hardware configurations (even if they support high bandwidth, such as [MikroTik CRS504-4XQ-IN][MikroTik100G], which supports 100GbE networks but only has 16MB of flash storage and 64MB of RAM, so it can basically only run its own RouterOS).
2. Some data center switches may not support SONiC due to their outdated models and lack of manufacturer plans.

Regarding the installation process, since each manufacturer's switch design is different, the underlying interfaces are also different, so the installation methods vary. These differences mainly focus on two areas:

1. Each manufacturer will have their own [SONiC Build][SONiCDevices], and some manufacturers will extend development on top of SONiC to support more features for their switches, such as [Dell Enterprise SONiC][DellSONiC] and [EdgeCore Enterprise SONiC][EdgeCoreSONiC]. Therefore, you need to choose the corresponding version based on your switch model.
2. Each manufacturer's switch will also support different installation methods, some using USB to flash the ROM directly, and some using ONIE for installation. This configuration needs to be done according to your specific switch.

Although the installation methods may vary, the overall steps are similar. Please contact your manufacturer to obtain the corresponding installation documentation and follow the instructions to complete the installation.

## Configure the Switch

After installation, we need to perform some basic settings. Some settings are common, and we will summarize them here.

### Set the admin password

The default SONiC account and password is `admin` and `YourPaSsWoRd`. Using default password is obviously not secure. To change the password, we can run the following command:

```bash
sudo passwd admin
```

### Set fan speed

Data center switches are usually very noisy! For example, the switch I use is Arista 7050QX-32S, which has 4 fans that can spin up to 17000 RPM. Even if it is placed in the garage, the high-frequency whining can still be heard behind 3 walls on the second floor. Therefore, if you are using it at home, it is recommended to adjust the fan speed.

Unfortunately, [SONiC does not have CLI control over fan speed][SONiCThermal], so we need to manually modify the configuration file in the pmon container to adjust the fan speed.

```bash
# Enter the pmon container
sudo docker exec -it pmon bash

# Use pwmconfig to detect all PWM fans and create a configuration file. The configuration file will be created at /etc/fancontrol.
pwmconfig

# Start fancontrol and make sure it works. If it doesn't work, you can run fancontrol directly to see what's wrong.
VERBOSE=1 /etc/init.d/fancontrol start
VERBOSE=1 /etc/init.d/fancontrol status

# Exit the pmon container
exit

# Copy the configuration file from the container to the host, so that the configuration will not be lost after reboot.
# This command needs to know what is the model of your switch. For example, the command I need to run here is as follows. If your switch model is different, please modify it accordingly.
sudo docker cp pmon:/etc/fancontrol /usr/share/sonic/device/x86_64-arista_7050_qx32s/fancontrol
```

### Set the Switch Management Port IP

Data center switches usually can be connected via Serial Console, but its speed is very slow. Therefore, after installation, it is better to set up the Management Port as soon as possible, then use SSH connection.

Generally, the management port is named eth0, so we can use SONiC's configuration command to set it up:

```bash
# sudo config interface ip add eth0 <ip-cidr> <gateway>
# IPv4
sudo config interface ip add eth0 192.168.1.2/24 192.168.1.1

# IPv6
sudo config interface ip add eth0 2001::8/64 2001::1
```

### Create Network Configuration

A newly installed SONiC switch will have a default network configuration, which has many issues, such as using 10.0.0.0 IP on Ethernet0, as shown below:

```bash
admin@sonic:~$ show ip interfaces
Interface    Master    IPv4 address/mask    Admin/Oper    BGP Neighbor    Neighbor IP
-----------  --------  -------------------  ------------  --------------  -------------
Ethernet0              10.0.0.0/31          up/up         ARISTA01T2      10.0.0.1
Ethernet4              10.0.0.2/31          up/up         ARISTA02T2      10.0.0.3
Ethernet8              10.0.0.4/31          up/up         ARISTA03T2      10.0.0.5
```

Therefore, we need to update the ports with a new network configuration. A simple method is to create a VLAN and use VLAN Routing:

```bash
# Create untagged VLAN
sudo config vlan add 2

# Add IP to VLAN
sudo config interface ip add Vlan2 10.2.0.0/24

# Remove all default IP settings
show ip interfaces | tail -n +3 | grep Ethernet | awk '{print "sudo config interface ip remove", $1, $2}' > oobe.sh; chmod +x oobe.sh; ./oobe.sh

# Add all ports to the new VLAN
show interfaces status | tail -n +3 | grep Ethernet | awk '{print "sudo config vlan member add -u 2", $1}' > oobe.sh; chmod +x oobe.sh; ./oobe.sh

# Enable proxy ARP, so the switch can respond to ARP requests from hosts
sudo config vlan proxy_arp 2 enabled

# Save the config, so it will be persistent after reboot
sudo config save -y
```

That's it! Now we can use `show vlan brief` to check it:

```text
admin@sonic:~$ show vlan brief
+-----------+--------------+-------------+----------------+-------------+-----------------------+
|   VLAN ID | IP Address   | Ports       | Port Tagging   | Proxy ARP   | DHCP Helper Address   |
+===========+==============+=============+================+=============+=======================+
|         2 | 10.2.0.0/24  | Ethernet0   | untagged       | enabled     |                       |
...
|           |              | Ethernet124 | untagged       |             |                       |
+-----------+--------------+-------------+----------------+-------------+-----------------------+
```

### Configure the Host

If you only have one host at home using multiple NICs to connect to the switch for testing, we need to update some settings on the host to ensure that traffic flows through the NIC and the switch. Otherwise, feel free to skip this step.

There are many online guides for this, such as using DNAT and SNAT in iptables to create a virtual address. However, after some experiments, I found that the simplest way is to move one of the NICs to a new network namespace, even if it uses the same IP subnet, it will still work.

For example, if I use Netronome Agilio CX 2x40GbE at home, it will create two interfaces: `enp66s0np0` and `enp66s0np1`. Here, we can move `enp66s0np1` to a new network namespace and configure the IP address:

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

That's it! We can start testing it using iperf and confirm on the switch:

```bash
# On the host (enp66s0np0 has IP 10.2.0.10 assigned)
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

# Confirm on the switch
admin@sonic:~$ show interfaces counters
      IFACE    STATE       RX_OK        RX_BPS    RX_UTIL    RX_ERR    RX_DRP    RX_OVR       TX_OK        TX_BPS    TX_UTIL    TX_ERR    TX_DRP    TX_OVR
-----------  -------  ----------  ------------  ---------  --------  --------  --------  ----------  ------------  ---------  --------  --------  --------
  Ethernet4        U   2,580,140  6190.34 KB/s      0.12%         0     3,783         0  51,263,535  2086.64 MB/s     41.73%         0         0         0
 Ethernet12        U  51,261,888  2086.79 MB/s     41.74%         0         1         0   2,580,317  6191.00 KB/s      0.12%         0         0         0
```

# References

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