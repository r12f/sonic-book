# Redis数据库

首先，在SONiC里面最核心的服务，自然是当之无愧的中心数据库Redis了！它的主要目的有两个：存储所有服务的配置和状态，并且为各个服务提供通信的媒介。

为了提供这些功能，SONiC会在Redis中创建一个名为`sonic-db`的数据库实例，其配置和分库信息我们可以在`/var/run/redis/sonic-db/database_config.json`中找到：

```bash
admin@sonic:~$ cat /var/run/redis/sonic-db/database_config.json
{
    "INSTANCES": {
        "redis": {
            "hostname": "127.0.0.1",
            "port": 6379,
            "unix_socket_path": "/var/run/redis/redis.sock",
            "persistence_for_warm_boot": "yes"
        }
    },
    "DATABASES": {
        "APPL_DB": { "id": 0, "separator": ":", "instance": "redis" },
        "ASIC_DB": { "id": 1, "separator": ":", "instance": "redis" },
        "COUNTERS_DB": { "id": 2, "separator": ":", "instance": "redis" },
        "LOGLEVEL_DB": { "id": 3, "separator": ":", "instance": "redis" },
        "CONFIG_DB": { "id": 4, "separator": "|", "instance": "redis" },
        "PFC_WD_DB": { "id": 5, "separator": ":", "instance": "redis" },
        "FLEX_COUNTER_DB": { "id": 5, "separator": ":", "instance": "redis" },
        "STATE_DB": { "id": 6, "separator": "|", "instance": "redis" },
        "SNMP_OVERLAY_DB": { "id": 7, "separator": "|", "instance": "redis" },
        "RESTAPI_DB": { "id": 8, "separator": "|", "instance": "redis" },
        "GB_ASIC_DB": { "id": 9, "separator": ":", "instance": "redis" },
        "GB_COUNTERS_DB": { "id": 10, "separator": ":", "instance": "redis" },
        "GB_FLEX_COUNTER_DB": { "id": 11, "separator": ":", "instance": "redis" },
        "APPL_STATE_DB": { "id": 14, "separator": ":", "instance": "redis" }
    },
    "VERSION": "1.0"
}
```

虽然我们可以看到SONiC中的数据库有十来个，但是我们大部分时候只需要关注以下几个最重要的数据库就可以了：

- **CONFIG_DB（ID = 4）**：存储所有服务的**配置信息**，比如端口配置，VLAN配置等等。它代表着**用户想要交换机达到的状态**的数据模型，这也是所有CLI和外部应用程序修改配置时的主要操作对象。
- **APPL_DB（Application DB, ID = 0）**：存储**所有服务的内部状态信息**。这些信息有两种：一种是各个服务在读取了CONFIG_DB的配置信息后，自己计算出来的。我们可以理解为**各个服务想要交换机达到的状态**（Goal State），还有一种是当最终硬件状态发生变化被写回时，有些服务会直接写回到APPL_DB，而不是我们下面马上要介绍的STATE_DB。这些信息我们可以理解为**各个服务认为交换机当前的状态**（Current State）。
- **STATE_DB（ID = 6）**：存储着交换机**各个部件当前的状态**（Current State）。当SONiC中的服务收到了STATE_DB的状态变化，但是发现和Goal State不一致的时候，SONiC就会重新下发配置，直到两者一致。（当然，对于那些回写到APPL_DB状态，服务就会监听APPL_DB的变化，而不是STATE_DB了。）
- **ASIC_DB（ID = 1）**：存储着**SONiC想要交换机ASIC达到状态信息**，比如，ACL，路由等等。和APPL_DB不同，这个数据库里面的数据模型是面向ASIC设计的，而不是面向服务抽象的。这样做的目的是为了方便各个厂商进行SAI和ASIC驱动的开发。

这里，我们会发现一个很直观的问题：交换机里面这么多服务，难道所有的配置和状态都放在一个数据库里面没有隔离的么？如果两个服务用了同一个Redis Key怎么办呢？这个问题非常的好，SONiC的解决也很直接，那就是在每个数据库里面继续分表！

我们知道Redis在每个数据库里面并没有表的概念，而是使用key-value的方式来存储数据。所以，为了进一步分表，SONiC的解决方法是将表的名字放入key中，并且使用分隔符将表和key隔开。上面的配置文件中`separator`字段就是做这个了。比如：`APPL_DB`中的`PORT_TABLE`表中的`Ethernet4`端口的状态，我们可以通过`PORT_TABLE:Ethernet4`来获取，如下：

```bash
127.0.0.1:6379> select 0
OK

127.0.0.1:6379> hgetall PORT_TABLE:Ethernet4
 1) "admin_status"
 2) "up"
 3) "alias"
 4) "Ethernet6/1"
 5) "index"
 6) "6"
 7) "lanes"
 8) "13,14,15,16"
 9) "mtu"
10) "9100"
11) "speed"
12) "40000"
13) "description"
14) ""
15) "oper_status"
16) "up"
```

当然在SONiC中，不仅仅是数据模型，包括通信机制，都是使用类似的方法来实现“表”级别的隔离的。

# 参考资料

1. [SONiC Architecture][SONiCArch]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture