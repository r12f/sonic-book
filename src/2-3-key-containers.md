# Key containers

One of the most distinctive features of SONiC's design is containerization.

From the design diagram of SONiC, we can see that all services in SONiC run in the form of containers. After logging into the switch, we can use the `docker ps` command to see all containers that are currently running:

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

Here we will briefly introduce these containers.

## Database Container: `database`

This container contains the central database - Redis, which we have mentioned multiple times. It stores all the configuration and status of the switch, and SONiC also uses it to provide the underlying communication mechanism to various services.

By entering this container via Docker, we can see the running Redis process:

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

How does other container access this Redis database?

The answer is through Unix Socket. We can see this Unix Socket in the database container, which is mapped from the `/var/run/redis` directory on the switch.

```bash
# In database container
root@sonic:/# ls /var/run/redis
redis.pid  redis.sock  sonic-db

# On host
admin@sonic:~$ ls /var/run/redis
redis.pid  redis.sock  sonic-db
```

Then SONiC maps `/var/run/redis` folder into all relavent containers, allowing other services to access the central database. For example, the swss container:

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

## SWitch State Service Container: `swss`

This container can be considered the most critical container in SONiC. **It is the brain of SONiC**, running numerous `*syncd` and `*mgrd` services to manage various configurations of the switch, such as Port, neighbor, ARP, VLAN, Tunnel, etc. Additionally, it runs the `orchagent`, which handles many configurations and state changes related to the ASIC.

We have already discussed the general functions and processes of these services, so we won't repeat them here. We can use the `ps` command to see the services running in this container:

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

## ASIC Management Container: `syncd`

This container is mainly used for managing the ASIC on the switch, running the `syncd` service. The SAI (Switch Abstraction Interface) implementation and ASIC Driver provided by various vendors are placed in this container. It allows SONiC to support multiple different ASICs without modifying the upper-layer services. In other words, without this container, SONiC would be a brain in a jar, capable of only thinking but nothing else.

We don't have too many services running in the syncd container, mainly syncd. We can check them using the `ps` command, and in the `/usr/lib` directory, we can find the enormous SAI file compiled to support the ASIC:

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

## Feature Containers

There are many containers in SONiC designed to implement specific features. These containers usually have special external interfaces (non-SONiC CLI and REST API) and implementations (non-OS or ASIC), such as:

- `bgp`: Container for implementing the BGP and other routing protocol (Border Gateway Protocol)
- `lldp`: Container for implementing the LLDP protocol (Link Layer Discovery Protocol)
- `teamd`: Container for implementing Link Aggregation
- `snmp`: Container for implementing the SNMP protocol (Simple Network Management Protocol)

Similar to SWSS, these containers also run the services we mentioned earlier to adapt to SONiC's architecture:

- Configuration management and deployment (similar to `*mgrd`): `lldpmgrd`, `zebra` (bgp)
- State synchronization (similar to `*syncd`): `lldpsyncd`, `fpmsyncd` (bgp), `teamsyncd`
- Service implementation or external interface (`*d`): `lldpd`, `bgpd`, `teamd`, `snmpd`

## Management Service Container: `mgmt-framework`

In previous chapters, we have seen how to use SONiC's CLI to configure some aspects of the switch. However, in a production environment, manually logging into the switch and using the CLI to configure all switches is unrealistic. Therefore, SONiC provides a REST API to solve this problem. This REST API is implemented in the `mgmt-framework` container. We can check it using the `ps` command:

```bash
admin@sonic:~$ docker exec -it mgmt-framework bash
root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          16  0.3  1.2 1472804 52036 pts/0   Sl   16:20   0:02 /usr/sbin/rest_server -ui /rest_ui -logtostderr -cert /tmp/cert.pem -key /tmp/key.pem
...
```

In addition to the REST API, SONiC can also be managed through other methods such as gNMI, all of which run in this container. The overall architecture is shown in the figure below [\[2\]][SONiCMgmtFramework]:

![](assets/chapter-2/sonic-mgmt-framework.jpg)

Here we can also see that the CLI we use can be implemented by calling this REST API at the bottom layer.

## Platform Monitor Container: `pmon`

The services in this container are mainly used to monitor the basic hardware status of the switch, such as temperature, power supply, fans, SFP events, etc. Similarly, we can use the `ps` command to check the services running in this container:

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

The purpose of most of these services can be told from their names. The only one that is not so obvious is `xcvrd`, where xcv stands for transceiver. It is used to monitor the optical modules of the switch, such as SFP, QSFP, etc.

# References

1. [SONiC Architecture][SONiCArch]
2. [SONiC Management Framework][SONiCMgmtFramework]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCMgmtFramework]: https://github.com/sonic-net/SONiC/blob/master/doc/mgmt/Management%20Framework.md