# 核心容器

SONiC的设计中最具特色的地方：容器化。

从SONiC的上面的设计图中，我们可以看出来，SONiC中，所有的服务都是以容器的形式存在的。在登录进交换机之后，我们可以通过`docker ps`命令来查看当前运行的容器：

```bash
admin@sonic:~$ docker ps
CONTAINER ID   IMAGE                                COMMAND                  CREATED      STATUS        PORTS     NAMES
ddf09928ec58   docker-snmp:latest                   "/usr/local/bin/supe…"   2 days ago   Up 32 hours             snmp
c480f3cf9dd7   docker-sonic-mgmt-framework:latest   "/usr/local/bin/supe…"   2 days ago   Up 32 hours             mgmt-framework
3655aff31161   docker-lldp:latest                   "/usr/bin/docker-lld…"   2 days ago   Up 32 hours             lldp
78f0b12ed10e   docker-platform-monitor:latest       "/usr/bin/docker_ini…"   2 days ago   Up 32 hours             pmon
f9d9bcf6c9a6   docker-router-advertiser:latest      "/usr/bin/docker-ini…"   2 days ago   Up 32 hours             radv
2e5dbee95844   docker-fpm-frr:latest                "/usr/bin/docker_ini…"   2 days ago   Up 32 hours             bgp
bdfa58009226   docker-syncd-brcm:latest             "/usr/local/bin/supe…"   2 days ago   Up 32 hours             syncd
655e550b7a1b   docker-teamd:latest                  "/usr/local/bin/supe…"   2 days ago   Up 32 hours             teamd
1bd55acc181c   docker-orchagent:latest              "/usr/bin/docker-ini…"   2 days ago   Up 32 hours             swss
bd20649228c8   docker-eventd:latest                 "/usr/local/bin/supe…"   2 days ago   Up 32 hours             eventd
b2f58447febb   docker-database:latest               "/usr/local/bin/dock…"   2 days ago   Up 32 hours             database
```

这里我们来简单介绍一下这些容器。

## 数据库容器：database

这个容器中运行的就是我们多次提到的SONiC中的中心数据库Redis了，它里面存放着所有交换机的配置和状态信息，SONiC也是主要通过它来向各个服务提供底层的通信机制。

我们通过docker进入这个容器，就可以看到里面正在运行的redis进程了：

```bash
admin@sonic:~$ sudo docker exec -it database bash

root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          82 13.7  1.7 130808 71692 pts/0    Sl   Apr26 393:27 /usr/bin/redis-server 127.0.0.1:6379
...

root@sonic:/# cat /var/run/redis/redis.pid
82
```

那么别的容器是如何来访问这个Redis数据库的呢？答案是通过Unix Socket。我们可以在database容器中看到这个Unix Socket，它将交换机上的`/var/run/redis`目录map进database容器，让database容器可以创建这个socket：

```bash
# In database container
root@sonic:/# ls /var/run/redis
redis.pid  redis.sock  sonic-db

# On host
admin@sonic:~$ ls /var/run/redis
redis.pid  redis.sock  sonic-db
```

然后再将这个socket给map到其他的容器中，这样所有容器就都可以来访问这个中心数据库啦，比如，swss容器：

```bash
admin@sonic:~$ docker inspect swss
...
        "HostConfig": {
            "Binds": [
                ...
                "/var/run/redis:/var/run/redis:rw",
                ...
            ],
...
```

## 交换机状态管理容器：swss（Switch State Service）

这个容器可以说是SONiC中最关键的容器了，**它是SONiC的大脑**，里面运行着大量的`*syncd`和`*mgrd`服务，用来管理交换机方方面面的配置，比如Port，neighbor，ARP，VLAN，Tunnel等等等等。另外里面还运行着上面提到的`orchagent`，用来统一处理和ASIC相关的配置和状态变化。

这些服务大概的功能和流程我们上面已经提过了，所以就不再赘述了。这里我们可以通过`ps`命令来看一下这个容器中运行的服务：

```bash
admin@sonic:~$ docker exec -it swss bash
root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          43  0.0  0.2  91016  9688 pts/0    Sl   Apr26   0:18 /usr/bin/portsyncd
root          49  0.1  0.6 558420 27592 pts/0    Sl   Apr26   4:31 /usr/bin/orchagent -d /var/log/swss -b 8192 -s -m 00:1c:73:f2:bc:b4
root          74  0.0  0.2  91240  9776 pts/0    Sl   Apr26   0:19 /usr/bin/coppmgrd
root          93  0.0  0.0   4400  3432 pts/0    S    Apr26   0:09 /bin/bash /usr/bin/arp_update
root          94  0.0  0.2  91008  8568 pts/0    Sl   Apr26   0:09 /usr/bin/neighsyncd
root          96  0.0  0.2  91168  9800 pts/0    Sl   Apr26   0:19 /usr/bin/vlanmgrd
root          99  0.0  0.2  91320  9848 pts/0    Sl   Apr26   0:20 /usr/bin/intfmgrd
root         103  0.0  0.2  91136  9708 pts/0    Sl   Apr26   0:19 /usr/bin/portmgrd
root         104  0.0  0.2  91380  9844 pts/0    Sl   Apr26   0:20 /usr/bin/buffermgrd -l /usr/share/sonic/hwsku/pg_profile_lookup.ini
root         107  0.0  0.2  91284  9836 pts/0    Sl   Apr26   0:20 /usr/bin/vrfmgrd
root         109  0.0  0.2  91040  8600 pts/0    Sl   Apr26   0:19 /usr/bin/nbrmgrd
root         110  0.0  0.2  91184  9724 pts/0    Sl   Apr26   0:19 /usr/bin/vxlanmgrd
root         112  0.0  0.2  90940  8804 pts/0    Sl   Apr26   0:09 /usr/bin/fdbsyncd
root         113  0.0  0.2  91140  9656 pts/0    Sl   Apr26   0:20 /usr/bin/tunnelmgrd
root         208  0.0  0.0   5772  1636 pts/0    S    Apr26   0:07 /usr/sbin/ndppd
...
```

## ASIC管理容器：syncd

这个容器中主要是用于管理交换机上的ASIC的，里面运行着`syncd`服务。我们之前提到的各个厂商提供的SAI（Switch Abstraction Interface）和ASIC Driver都是放在这个容器中的。正是因为这个容器的存在，才使得SONiC可以支持多种不同的ASIC，而不需要修改上层的服务。换句话说，如果没有这个容器，那SONiC就是一个缸中大脑，除了一些基本的配置，其他只能靠想的，什么都干不了。

在syncd容器中运行的服务并不多，就是syncd，我们可以通过`ps`命令来查看，而在`/usr/lib`目录下，我们也可以找到这个为了支持ASIC而编译出来的巨大无比的SAI文件：

```bash
admin@sonic:~$ docker exec -it syncd bash

root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          20  0.0  0.0  87708  1544 pts/0    Sl   Apr26   0:00 /usr/bin/dsserve /usr/bin/syncd --diag -u -s -p /etc/sai.d/sai.profile -b /tmp/break_before_make_objects
root          32 10.7 14.9 2724404 599408 pts/0  Sl   Apr26 386:49 /usr/bin/syncd --diag -u -s -p /etc/sai.d/sai.profile -b /tmp/break_before_make_objects
...

root@sonic:/# ls -lh /usr/lib
total 343M
...
lrwxrwxrwx 1 root root   13 Apr 25 04:38 libsai.so.1 -> libsai.so.1.0
-rw-r--r-- 1 root root 343M Feb  1 06:10 libsai.so.1.0
...
```

## 各种实现特定功能的容器

SONiC中还有很多的容器是为了实现一些特定功能而存在的。这些容器一般都有着特殊的外部接口（非SONiC CLI和REST API）和实现（非OS或ASIC），比如：

- bgp：用来实现BGP协议（Border Gateway Protocol，边界网关协议）的容器
- lldp：用来实现LLDP协议（Link Layer Discovery Protocol，链路层发现协议）的容器
- teamd：用来实现Link Aggregation（链路聚合）的容器
- snmp：用来实现SNMP协议（Simple Network Management Protocol，简单网络管理协议）的容器

和SWSS类似，为了适应SONiC的架构，它们中间也都会运行着上面我们提到的那几种服务：

- 配置管理和下发（类似`*mgrd`）：`lldpmgrd`，`zebra`（bgp）
- 状态同步（类似`*syncd`）：`lldpsyncd`，`fpmsyncd`（bgp），`teamsyncd`
- 服务实现或者外部接口（`*d`）：`lldpd`，`bgpd`，`teamd`，`snmpd`

## 管理服务容器：mgmt-framework

我们在之前的章节中已经看过如何使用SONiC的CLI来进行一些交换机的配置，但是在实际生产环境中，手动登录交换机使用CLI来配置所有的交换机是不现实的，所以SONiC提供了一个REST API来解决这个问题。这个REST API的实现就是在`mgmt-framework`容器中。我们可以通过`ps`命令来查看：

```bash
admin@sonic:~$ docker exec -it mgmt-framework bash
root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          16  0.3  1.2 1472804 52036 pts/0   Sl   16:20   0:02 /usr/sbin/rest_server -ui /rest_ui -logtostderr -cert /tmp/cert.pem -key /tmp/key.pem
...
```

其实除了REST API，SONiC还可以通过其他方式来进行管理，如gNMI，这些也都是运行在这个容器中的。其整体架构如下图所示 [\[2\]][SONiCMgmtFramework]：

![](assets/chapter-2/sonic-mgmt-framework.jpg)

这里我们也可以发现，其实我们使用的CLI，底层也是通过调用这个REST API来实现的～

## 平台监控容器：pmon（Platform Monitor）

这个容器里面的服务基本都是用来监控交换机一些基础硬件的运行状态的，比如温度，电源，风扇，SFP事件等等。同样，我们可以用`ps`命令来查看这个容器中运行的服务：

```bash
admin@sonic:~$ docker exec -it pmon bash
root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          28  0.0  0.8  49972 33192 pts/0    S    Apr26   0:23 python3 /usr/local/bin/ledd
root          29  0.9  1.0 278492 43816 pts/0    Sl   Apr26  34:41 python3 /usr/local/bin/xcvrd
root          30  0.4  1.0  57660 40412 pts/0    S    Apr26  18:41 python3 /usr/local/bin/psud
root          32  0.0  1.0  57172 40088 pts/0    S    Apr26   0:02 python3 /usr/local/bin/syseepromd
root          33  0.0  1.0  58648 41400 pts/0    S    Apr26   0:27 python3 /usr/local/bin/thermalctld
root          34  0.0  1.3  70044 53496 pts/0    S    Apr26   0:46 /usr/bin/python3 /usr/local/bin/pcied
root          42  0.0  0.0  55320  1136 ?        Ss   Apr26   0:15 /usr/sbin/sensord -f daemon
root          45  0.0  0.8  58648 32220 pts/0    S    Apr26   2:45 python3 /usr/local/bin/thermalctld
...
```

其中大部分的服务从名字我们就能猜出来是做什么的了，中间只有xcvrd不是那么明显，这里xcvr是transceiver的缩写，它是用来监控交换机的光模块的，比如SFP，QSFP等等。

# 参考资料

1. [SONiC Architecture][SONiCArch]
2. [SONiC Management Framework][SONiCMgmtFramework]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCMgmtFramework]: https://github.com/sonic-net/SONiC/blob/master/doc/mgmt/Management%20Framework.md