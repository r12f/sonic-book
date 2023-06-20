# 常用命令

为了帮助我们查看和配置SONiC的状态，SONiC提供了大量的CLI命令供我们调用。这些命令大多分为两类：`show`和`config`，他们的格式基本类似，大多都符合下面的格式：

```bash
show <object> [options]
config <object> [options]
```

SONiC的文档提供了非常详细的命令列表：[SONiC Command Line Interface Guide][SONiCCommands]，但是由于其命令众多，不便于我们初期的学习和使用，所以列出了一些平时最常用的命令和解释，供大家参考。

```admonish info
SONiC中的所有命令的子命令都可以只打前三个字母，来帮助我们有效的节约输入命令的时间，比如：

    show interface transceiver error-status
    
和下面这条命令是等价的：

    show int tra err

为了帮助大家记忆和查找，下面的命令列表都用的全名，但是大家在实际使用的时候，可以大胆的使用缩写来减少工作量。
```

```admonish info
如果遇到不熟悉的命令，都可以通过输入`-h`或者`--help`来查看帮助信息，比如：

    show -h
    show interface --help
    show interface transceiver --help

```

## General

```bash
show version

show uptime

show platform summary
```

## Config

```bash
sudo config reload
sudo config load_minigraph
sudo config save -y
```

## Docker相关

```bash
docker ps
```

```bash
docker top <container_id>|<container_name>
```

```admonish note

如果我们想对所有的docker container进行某个操作，我们可以通过`docker ps`命令来获取所有的container id，然后pipe到`tail -n +2`来去掉第一行的标题，从而实现批量调用。

比如，我们可以通过如下命令来查看所有container中正在运行的所有线程：

    $ for id in `docker ps | tail -n +2 | awk '{print $1}'`; do docker top $id; done
    UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD
    root                7126                7103                0                   Jun09               pts/0               00:02:24            /usr/bin/python3 /usr/local/bin/supervisord
    root                7390                7126                0                   Jun09               pts/0               00:00:24            python3 /usr/bin/supervisor-proc-exit-listener --container-name telemetry
    ...
```

## Interfaces / IPs

```bash
show interface status
show interface counters
show interface portchannel
show interface transceiver info
show interface transceiver error-status
sonic-clear counters

TODO: config
```

## MAC / ARP / NDP

```bash
# Show MAC (FDB) entries
show mac

# Show IP ARP table
show arp

# Show IPv6 NDP table
show ndp
```

## BGP / Routes

```bash
show ip/ipv6 bgp summary
show ip/ipv6 bgp network

show ip/ipv6 bgp neighbors [IP]

show ip/ipv6 route

TODO: add
config bgp shutdown neighbor <IP>
config bgp shutdown all

TODO: IPv6
```

## LLDP

```bash
# Show LLDP neighbors in table format
show lldp table

# Show LLDP neighbors details
show lldp neighbors
```

## VLAN

```bash
show vlan brief
```

## QoS相关

```bash
# Show PFC watchdog stats
show pfcwd stats
show queue counter
```

## ACL

```bash
show acl table
show acl rule
```

## MUXcable / Dual ToR

### Muxcable mode

```bash
config muxcable mode {active} {<portname>|all} [--json]
config muxcable mode active Ethernet4 [--json]
```

### Muxcable config

```bash
show muxcable config [portname] [--json]
```

### Muxcable status

```bash
show muxcable status [portname] [--json] 
```

### Muxcable firmware

```bash
# Firmware version:
show muxcable firmware version <port>

# Firmware download
# config muxcable firmware download <firmware_file> <port_name> 
sudo config muxcable firmware download AEC_WYOMING_B52Yb0_MS_0.6_20201218.bin Ethernet0

# Rollback:
# config muxcable firmware rollback <port_name>
sudo config muxcable firmware rollback Ethernet0
```

# 参考资料

1. [SONiC Command Line Interface Guide][SONiCCommands]

[SONiCCommands]: https://github.com/sonic-net/sonic-utilities/blob/master/doc/Command-Reference.md