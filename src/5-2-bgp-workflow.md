# BGP工作流

[BGP][BGP]可能是交换机里面最常用，最重要，或者线上使用的最多的功能了。这一节，我们就来深入的看一下BGP相关的工作流。

## BGP相关进程

SONiC使用[FRRouting][FRRouting]作为BGP的实现，用于负责BGP的协议处理。FRRouting是一个开源的路由软件，支持多种路由协议，包括BGP，OSPF，IS-IS，RIP，PIM，LDP等等。当FRR发布新版本后，SONiC会将其同步到[SONiC的FRR实现仓库：sonic-frr][SONiCFRR]中，每一个版本都对应这一个分支，比如`frr/8.2`。

FRR主要由两个大部分组成，第一个部分是各个协议的实现，这些进程的名字都叫做`*d`，而当它们收到路由更新的通知的时候，就会告诉第二个部分，也就是`zebra`进程，然后`zebra`进程会进行选路，并将最优的路由信息同步到kernel中，其主体结构如下图所示：

```
+----+  +----+  +-----+  +----+  +----+  +----+  +-----+
|bgpd|  |ripd|  |ospfd|  |ldpd|  |pbrd|  |pimd|  |.....|
+----+  +----+  +-----+  +----+  +----+  +----+  +-----+
     |       |        |       |       |       |        |
+----v-------v--------v-------v-------v-------v--------v
|                                                      |
|                         Zebra                        |
|                                                      |
+------------------------------------------------------+
       |                    |                   |
       |                    |                   |
+------v------+   +---------v--------+   +------v------+
|             |   |                  |   |             |
| *NIX Kernel |   | Remote dataplane |   | ........... |
|             |   |                  |   |             |
+-------------+   +------------------+   +-------------+
```

在SONiC中，这些FRR的进程都跑在`bgp`的容器中。另外，为了将FRR和Redis连接起来，SONiC在`bgp`容器中还会运行一个叫做`fpgsyncd`的进程（Forwarding Plane Manager syncd），它的主要功能是监听kernel的路由更新，然后将其同步到APP_DB中。但是因为这个进程不是FRR的一部分，所以它的实现被放在了[sonic-swss][SONiCSWSS]仓库中。

## BGP命令实现

由于BGP是使用FRR来实现的，所以自然而然的，`show`命令会将直接请求转发给FRR的`vtysh`，核心代码如下：

```python
# file: src/sonic-utilities/show/bgp_frr_v4.py
# 'summary' subcommand ("show ip bgp summary")
@bgp.command()
@multi_asic_util.multi_asic_click_options
def summary(namespace, display):
    bgp_summary = bgp_util.get_bgp_summary_from_all_bgp_instances(
        constants.IPV4, namespace, display)
    bgp_util.display_bgp_summary(bgp_summary=bgp_summary, af=constants.IPV4)

# file: src/sonic-utilities/utilities_common/bgp_util.py
def get_bgp_summary_from_all_bgp_instances(af, namespace, display):
    # IPv6 case is emitted here for simplicity
    vtysh_cmd = "show ip bgp summary json"
    
    for ns in device.get_ns_list_based_on_options():
        cmd_output = run_bgp_show_command(vtysh_cmd, ns)

def run_bgp_command(vtysh_cmd, bgp_namespace=multi_asic.DEFAULT_NAMESPACE, vtysh_shell_cmd=constants.VTYSH_COMMAND):
    cmd = ['sudo', vtysh_shell_cmd] + bgp_instance_id + ['-c', vtysh_cmd]
    output, ret = clicommon.run_command(cmd, return_cmd=True)
```

这里，我们也可以通过直接运行`vtysh`来进行验证：

```bash
root@7260cx3:/etc/sonic/frr# which vtysh
/usr/bin/vtysh

root@7260cx3:/etc/sonic/frr# vtysh

Hello, this is FRRouting (version 7.5.1-sonic).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

7260cx3# show ip bgp summary

IPv4 Unicast Summary:
BGP router identifier 10.1.0.32, local AS number 65100 vrf-id 0
BGP table version 6410
RIB entries 12809, using 2402 KiB of memory
Peers 4, using 85 KiB of memory
Peer groups 4, using 256 bytes of memory

Neighbor        V         AS   MsgRcvd   MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd   PfxSnt
10.0.0.57       4      64600      3702      3704        0    0    0 08:15:03         6401     6406
10.0.0.59       4      64600      3702      3704        0    0    0 08:15:03         6401     6406
10.0.0.61       4      64600      3705      3702        0    0    0 08:15:03         6401     6406
10.0.0.63       4      64600      3702      3702        0    0    0 08:15:03         6401     6406

Total number of neighbors 4
```

而`config`命令则是通过直接操作CONFIG_DB来实现的，核心代码如下：

```python
# file: src/sonic-utilities/config/main.py

@bgp.group(cls=clicommon.AbbreviationGroup)
def remove():
    "Remove BGP neighbor configuration from the device"
    pass

@remove.command('neighbor')
@click.argument('neighbor_ip_or_hostname', metavar='<neighbor_ip_or_hostname>', required=True)
def remove_neighbor(neighbor_ip_or_hostname):
    """Deletes BGP neighbor configuration of given hostname or ip from devices
       User can specify either internal or external BGP neighbor to remove
    """
    namespaces = [DEFAULT_NAMESPACE]
    removed_neighbor = False
    ...

    # Connect to CONFIG_DB in linux host (in case of single ASIC) or CONFIG_DB in all the
    # namespaces (in case of multi ASIC) and do the sepcified "action" on the BGP neighbor(s)
    for namespace in namespaces:
        config_db = ConfigDBConnector(use_unix_socket_path=True, namespace=namespace)
        config_db.connect()
        if _remove_bgp_neighbor_config(config_db, neighbor_ip_or_hostname):
            removed_neighbor = True
    ...
```

## BGP路由变更下发

路由变更几乎是SONiC中最重要的工作流，它的整个流程从`bgpd`进程开始，到最终通过SAI到达ASIC芯片，中间参与的进程较多，流程也较为复杂，但是弄清楚之后，我们就可以很好的理解SONiC的设计思想，并且举一反三的理解其他配置下发的工作流了。所以这一节，我们就一起来深入的分析一下它的整体流程。

首先，其整体工作流程如下：

```mermaid
sequenceDiagram
    autonumber
    participant kernel
    box purple bgp容器
    participant bgpd
    participant zebra
    participant fpmsyncd
    end
    box darkblue swss容器
    participant orchagent
    end
    box darkgreen syncd容器
    participant syncd
    end
```

而为了方便我们从代码层面上来理解，以下，我们把这个流程根据五个最主要的参与者分成五个部分来介绍。

### bgp容器处理路由变更

### zebra更新路由表

### fpmsyncd更新Redis中的路由配置

### orchagent处理路由配置变化

### syncd更新ASIC

# 参考资料

1. [SONiC Architecture][SONiCArch]
2. [Github repo: sonic-swss][SONiCSWSS]
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]
4. [Github repo: sonic-frr][SONiCFRR]
5. [Github repo: sonic-utilities][SONiCUtil]
6. [RFC 4271: A Border Gateway Protocol 4 (BGP-4)][BGP]
7. [FRRouting][FRRouting]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common
[SONiCFRR]: https://github.com/sonic-net/sonic-frr
[SONiCUtil]: https://github.com/sonic-net/sonic-utilities
[BGP]: https://datatracker.ietf.org/doc/html/rfc4271
[FRRouting]: https://frrouting.org/