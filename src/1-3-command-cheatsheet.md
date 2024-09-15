
# Common Commands

To help us check and configure the state of SONiC, SONiC provides a large number of CLI commands for us to use. These commands are mostly divided into two categories: `show` and `config`. Their formats are generally similar, mostly following the format below:

```bash
show <object> [options]
config <object> [options]
```

The SONiC documentation provides a very detailed list of commands: [SONiC Command Line Interface Guide][SONiCCommands], but due to the large number of commands, it is not very convenient for us to ramp up, so we listed some of the most commonly used commands and explanations for reference.

```admonish info
All subcommands in SONiC can be abbreviated to the first three letters to help us save time when entering commands. For example:

    show interface transceiver error-status
    
is equivalent to:

    show int tra err

To help with memory and lookup, the following command list uses full names, but in actual use, you can boldly use abbreviations to reduce workload.
```

```admonish info
If you encounter unfamiliar commands, you can view the help information by entering `-h` or `--help`, for example:

    show -h
    show interface --help
    show interface transceiver --help

```

## Basic system information

```bash
# Show system version, platform info and docker containers
show version

# Show system uptime
show uptime

# Show platform information, such as HWSKU
show platform summary
```

## Config

```bash
# Reload all config.
# WARNING: This will restart almost all services and will cause network interruption.
sudo config reload

# Save the current config from redis DB to disk, which makes the config persistent across reboots.
# NOTE: The config file is saved to `/etc/sonic/config_db.json`
sudo config save -y
```

## Docker Related

```bash
# Show all docker containers
docker ps

# Show processes running in a container
docker top <container_id>|<container_name>

# Enter the container
docker exec -it <container_id>|<container_name> bash
```

```admonish note

If we want to perform an operation on all docker containers, we can use the `docker ps` command to get all container IDs, then pipe to `tail -n +2` to remove the first line of the header, thus achieving batch calls.

For example, we can use the following command to view all threads running in all containers:

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
show interface transceiver eeprom
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

## QoS Related

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

# References

1. [SONiC Command Line Interface Guide][SONiCCommands]

[SONiCCommands]: https://github.com/sonic-net/sonic-utilities/blob/master/doc/Command-Reference.md