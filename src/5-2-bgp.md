# BGP

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

# 参考资料

1. [SONiC Architecture][SONiCArch]
2. [Github repo: sonic-swss][SONiCSWSS]
3. [Github repo: sonic-frr][SONiCFRR]
4. [RFC 4271: A Border Gateway Protocol 4 (BGP-4)][BGP]
5. [FRRouting][FRRouting]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCFRR]: https://github.com/sonic-net/sonic-frr
[BGP]: https://datatracker.ietf.org/doc/html/rfc4271
[FRRouting]: https://frrouting.org/