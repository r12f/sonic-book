# BGP

[BGP][BGP] might be the most commonly used and important feature in switches. In this section, we take a deeper look at BGP-related workflows.

## BGP Processes

SONiC uses [FRRouting][FRRouting] as its BGP implementation, responsible for handling the BGP protocol. FRRouting is an open-source routing software that supports multiple routing protocols, including BGP, OSPF, IS-IS, RIP, PIM, LDP, etc. When a new version of FRR is released, SONiC synchronizes it to the [SONiC FRR repository: sonic-frr][SONiCFRR], with each version corresponding to a branch such as `frr/8.2`.

FRR mainly consists of two major parts. The first part includes the implementations of each protocol, where processes are named `*d.` When they receive routing update notifications, they inform the second part, the "zebra" process. The `zebra` process performs route selection and synchronizes the best routing information to the kernel. Its main structure is shown below:

```text
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

In SONiC, these FRR processes all run inside the `bgp` container. In addition, to integrate FRR with Redis, SONiC runs a process called `fpmsyncd` (Forwarding Plane Manager syncd) within the `bgp` container. Its main function is to listen to kernel routing updates and synchronize them to the `APPL_DB`. Because it is not part of FRR, its implementation is located in the [sonic-swss][SONiCSWSS] repository.

# References

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