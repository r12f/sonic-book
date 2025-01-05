# BGP CLI and vtysh

## `show` Command

Since BGP is implemented using FRR, naturally, the `show` command will forward the direct request to FRR's `vtysh`. The key code is as follows:

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
    # The IPv6 case is omitted here for simplicity
    vtysh_cmd = "show ip bgp summary json"
    
    for ns in device.get_ns_list_based_on_options():
        cmd_output = run_bgp_show_command(vtysh_cmd, ns)

def run_bgp_command(vtysh_cmd, bgp_namespace=multi_asic.DEFAULT_NAMESPACE, vtysh_shell_cmd=constants.VTYSH_COMMAND):
    cmd = ['sudo', vtysh_shell_cmd] + bgp_instance_id + ['-c', vtysh_cmd]
    output, ret = clicommon.run_command(cmd, return_cmd=True)
```

We can also verify by running `vtysh` directly:

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

## `config` Command

Meanwhile, the `config` command directly operates on `CONFIG_DB` to achieve configuration changes. 

Take remove neighbor as an example. The key code is shown as follows:

```python
# file: src/sonic-utilities/config/main.py

@bgp.group(cls=clicommon.AbbreviationGroup)
def remove():
    "Remove BGP neighbor configuration from the device"
    pass

@remove.command('neighbor')
@click.argument('neighbor_ip_or_hostname', metavar='<neighbor_ip_or_hostname>', required=True)
def remove_neighbor(neighbor_ip_or_hostname):
    """Removes BGP neighbor configuration (internal or external) from the device"""
    namespaces = [DEFAULT_NAMESPACE]
    removed_neighbor = False
    // ...existing code...

    for namespace in namespaces:
        config_db = ConfigDBConnector(use_unix_socket_path=True, namespace=namespace)
        config_db.connect()
        if _remove_bgp_neighbor_config(config_db, neighbor_ip_or_hostname):
            removed_neighbor = True
    // ...existing code...
```

# References

1. [SONiC Architecture][SONiCArch]  
2. [Github repo: sonic-frr][SONiCFRR]  
3. [Github repo: sonic-utilities][SONiCUtil]  
4. [RFC 4271: A Border Gateway Protocol 4 (BGP-4)][BGP]  
5. [FRRouting][FRRouting]  

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture  
[SONiCFRR]: https://github.com/sonic-net/sonic-frr  
[SONiCUtil]: https://github.com/sonic-net/sonic-utilities  
[BGP]: https://datatracker.ietf.org/doc/html/rfc4271  
[FRRouting]: https://frrouting.org/