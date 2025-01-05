# Redis database

First and foremost, the core service in SONiC is undoubtedly the central database - Redis! It has two major purposes: storing the configuration and state of all services, and providing a communication channel for these services.

To provide these functionalities, SONiC creates a database instance in Redis named `sonic-db`. The configuration and database partitioning information can be found in `/var/run/redis/sonic-db/database_config.json`:

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

Although we can see that there are about a dozen databases in SONiC, most of the time we only need to focus on the following most important ones:

- **CONFIG_DB (ID = 4)**: Stores the **configuration** of all services, such as port configuration, VLAN configuration, etc. It represents the data model of the **desired state of the switch** as intended by the user. This is also the main object of operation when all CLI and external applications modify the configuration.
- **APPL_DB (Application DB, ID = 0)**: Stores **internal state information of all services**. It contains two types of information:
  - One is calculated by each service after reading the configuration information from CONFIG_DB, which can be understood as the **desired state of the switch** (Goal State) but from the perspective of each service.
  - The other is when the ASIC state changes and is written back, some services write directly to APPL_DB instead of the STATE_DB we will introduce next. This information can be understood as the **current state of the switch** as perceived by each service.
- **STATE_DB (ID = 6)**: Stores the **current state** of various components of the switch. When a service in SONiC receives a state change from STATE_DB and finds it inconsistent with the Goal State, SONiC will reapply the configuration until the two states are consistent. (Of course, for those states written back to APPL_DB, the service will monitor changes in APPL_DB instead of STATE_DB.)
- **ASIC_DB (ID = 1)**: Stores the **desired state information** of the switch ASIC in SONiC, such as ACL, routing, etc. Unlike APPL_DB, the data model in this database is designed for ASIC rather than service abstraction. This design facilitates the development of SAI and ASIC drivers by various vendors.

Now, we have an intuitive question: with so many services in the switch, are all configurations and states stored in a single database without isolation? What if two services use the same Redis Key? This is a very good question, and SONiC's solution is straightforward: continue to partition each database into tables!

We know that Redis does not have the concept of tables within each database but uses key-value pairs to store data. Therefore, to further partition tables, SONiC's solution is to include the table name in the key and separate the table and key with a delimiter. The `separator` field in the configuration file above serves this purpose. For example, the state of the `Ethernet4` port in the `PORT_TABLE` table in `APPL_DB` can be accessed using `PORT_TABLE:Ethernet4` as follows:

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
1)  "9100"
2)  "speed"
3)  "40000"
4)  "description"
5)  ""
6)  "oper_status"
7)  "up"
```

Of course, in SONiC, not only the data model but also the communication mechanism uses a similar method to achieve "table" level isolation.

# References

1. [SONiC Architecture][SONiCArch]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture