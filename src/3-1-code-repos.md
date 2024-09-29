# Code Repositories

The code of SONiC is hosted on the [sonic-net account on GitHub][SONiCGitHub], with over 30 repositories. It can be a bit overwhelming at first, but don't worry, we'll go through them together here.

## Core Repositories

First, let's look at the two most important core repositories in SONiC: SONiC and sonic-buildimage.

### Landing Repository: `SONiC`

<https://github.com/sonic-net/SONiC>

This repository contains the SONiC Landing Page and a large number of documents, Wiki, tutorials, slides from past talks, and so on. This repository is the most commonly used by newcomers, but note that there is **no code** in this repository, only documentation.

### Image Build Repository: `sonic-buildimage`

<https://github.com/sonic-net/sonic-buildimage>

Why is this build repository so important to us? Unlike other projects, **the build repository of SONiC is actually its main repository**! This repository contains:

- All the feature implementation repositories, in the form of git submodules (under the `src` directory).
- Support files for each device from switch manufactures (under the `device` directory), such as device configuration files for each model of switch, scripts, and so on. For example, my switch is an Arista 7050QX-32S, so I can find its support files in the `device/arista/x86_64-arista_7050_qx32s` directory.
- Support files provided by all ASIC chip manufacturers (in the `platform` directory), such as drivers, BSP, and low-level support scripts for each platform. Here we can see support files from almost all major chip manufacturers, such as Broadcom, Mellanox, etc., as well as implementations for simulated software switches, such as vs and p4. But for protecting IPs from each vendor, most of the time, the repo only contains the Makefiles that downloads these things for build purpose.
- Dockerfiles for building all container images used by SONiC (in the `dockers` directory).
- Various general configuration files and scripts (in the `files` directory).
- Dockerfiles for the build containers used for building (in the `sonic-slave-*` directories).
- And more...

Because this repository brings all related resources together, we basically only need to checkout this single repository to get all SONiC's code. It makes searching and navigating the code much more convenient than checking out the repos one by one!

## Feature Repositories

In addition to the core repositories, SONiC also has many feature repositories, which contain the implementations of various containers and services. These repositories are imported as submodules in the `src` directory of sonic-buildimage. If we would like to modify and contribute to SONiC, we also need to understand them.

### SWSS (Switch State Service) Related Repositories

As introduced in the previous section, the SWSS container is the brain of SONiC. In SONiC, it consists of two repositories: [sonic-swss-common](https://github.com/sonic-net/sonic-swss-common) and [sonic-swss](https://github.com/sonic-net/sonic-swss).

#### SWSS Common Library: `sonic-swss-common`

The first one is the common library: `sonic-swss-common` (<https://github.com/sonic-net/sonic-swss-common>).

This repository contains all the common functionalities needed by `*mgrd` and `*syncd` services, such as logger, JSON, netlink encapsulation, Redis operations, and various inter-service communication mechanisms based on Redis. Although it was initially intended for swss services, its extensive functionalities have led to its use in many other repositories, such as `swss-sairedis` and `swss-restapi`.

#### Main SWSS Repository: `sonic-swss`

Next is the main SWSS repository: `sonic-swss` (<https://github.com/sonic-net/sonic-swss>).

In this repository, we can find:

- Most of the `*mgrd` and `*syncd` services: `orchagent`, `portsyncd/portmgrd/intfmgrd`, `neighsyncd/nbrmgrd`, `natsyncd/natmgrd`, `buffermgrd`, `coppmgrd`, `macsecmgrd`, `sflowmgrd`, `tunnelmgrd`, `vlanmgrd`, `vrfmgrd`, `vxlanmgrd`, and more.
- `swssconfig`: Located in the `swssconfig` directory, used to restore FDB and ARP tables during fast reboot.
- `swssplayer`: Also in the `swssconfig` directory, used to record all configuration operations performed through SWSS, allowing us to replay them for troubleshooting and debugging.
- Even some services not in the SWSS container, such as `fpmsyncd` (BGP container) and `teamsyncd/teammgrd` (teamd container).

### SAI/Platform Related Repositories

Next is the Switch Abstraction Interface (SAI). [Although SAI was proposed by Microsoft and released version 0.1 in March 2015](https://www.opencompute.org/documents/switch-abstraction-interface-ocp-specification-v0-2-pdf), [by September 2015, before SONiC had even released its first version, it was already accepted by OCP as a public standard](https://azure.microsoft.com/en-us/blog/switch-abstraction-interface-sai-officially-accepted-by-the-open-compute-project-ocp/). This shows how quickly SONiC and SAI was getting supports from the community and vendors.

Overall, the SAI code is divided into two parts:

- OpenComputeProject/SAI under OCP: <https://github.com/opencomputeproject/SAI>. This repository contains all the code related to the SAI standard, including SAI header files, behavior models, test cases, documentation, and more.
- sonic-sairedis under SONiC: <https://github.com/sonic-net/sonic-sairedis>. This repository contains all the code used by SONiC to interact with SAI, such as the syncd service and various debugging tools like `saiplayer` for replay and `saidump` for exporting ASIC states.

In addition to these two repositories, there is another platform-related repository, such as [sonic-platform-vpp](https://github.com/sonic-net/sonic-platform-vpp), which uses SAI interfaces to implement data plane functionalities through VPP, essentially acting as a high-performance soft switch. I personally feel it might be merged into the buildimage repository in the future as part of the platform directory.

### Management Service (mgmt) Related Repositories

Next are all the repositories related to [management services][SONiCMgmtFramework] in SONiC:

| Name | Description |
| --- | --- |
| [sonic-mgmt-common](https://github.com/sonic-net/sonic-mgmt-common) | Base library for management services, containing `translib`, YANG model-related code |
| [sonic-mgmt-framework](https://github.com/sonic-net/sonic-mgmt-framework) | REST Server implemented in Go, acting as the REST Gateway in the architecture diagram below (process name: `rest_server`) |
| [sonic-gnmi](https://github.com/sonic-net/sonic-gnmi) | Similar to sonic-mgmt-framework, this is the gNMI (gRPC Network Management Interface) Server based on gRPC in the architecture diagram below |
| [sonic-restapi](https://github.com/sonic-net/sonic-restapi) | Another configuration management REST Server implemented in Go. Unlike mgmt-framework, this server directly operates on CONFIG_DB upon receiving messages, instead of using translib (not shown in the diagram, process name: `go-server-server`) |
| [sonic-mgmt](https://github.com/sonic-net/sonic-mgmt) | Various automation scripts (in the `ansible` directory), tests (in the `tests` directory), test bed setup and test reporting (in the `test_reporting` directory), and more |

Here is the architecture diagram of SONiC management services for reference [\[4\]][SONiCMgmtFramework]:

![](assets/chapter-3/sonic-mgmt-framework.jpg)

### Platform Monitoring Related Repositories: `sonic-platform-common` and `sonic-platform-daemons`

The following two repositories are related to platform monitoring and control, such as LEDs, fans, power supplies, thermal control, and more:

| Name | Description |
| --- | --- |
| [sonic-platform-common](https://github.com/sonic-net/sonic-platform-common) | A base package provided to manufacturers, defining interfaces for accessing fans, LEDs, power management, thermal control, and other modules, all implemented in Python |
| [sonic-platform-daemons](https://github.com/sonic-net/sonic-platform-daemons) | Contains various monitoring services running in the pmon container in SONiC, such as `chassisd`, `ledd`, `pcied`, `psud`, `syseepromd`, `thermalctld`, `xcvrd`, `ycabled`. All these services are implemented in Python, and used for monitoring and controlling the platform modules, by calling the interface implementations provided by manufacturers.  |

### Other Feature Repositories

In addition to the repositories above, SONiC has many repositories implementing various functionalities. They can be services or libraries described in the table below:

| Repository | Description |
| --- | --- |
| [sonic-frr](https://github.com/sonic-net/sonic-frr) | FRRouting, implementing various routing protocols, so in this repository, we can find implementations of routing-related processes like `bgpd`, `zebra`, etc. |
| [sonic-snmpagent](https://github.com/sonic-net/sonic-snmpagent) | Implementation of [AgentX](https://www.ietf.org/rfc/rfc2741.txt) SNMP subagent (`sonic_ax_impl`), used to connect to the Redis database and provide various information needed by snmpd. It can be understood as the control plane of snmpd, while snmpd is the data plane, responding to external SNMP requests |
| [sonic-linkmgrd](https://github.com/sonic-net/sonic-linkmgrd) | Dual ToR support, checking the status of links and controlling ToR connections |
| [sonic-dhcp-relay](https://github.com/sonic-net/sonic-dhcp-relay) | DHCP relay agent |
| [sonic-dhcpmon](https://github.com/sonic-net/sonic-dhcpmon) | Monitors the status of DHCP and reports to the central Redis database |
| [sonic-dbsyncd](https://github.com/sonic-net/sonic-dbsyncd) | `lldp_syncd` service, but the repository name is not well-chosen, called dbsyncd |
| [sonic-pins](https://github.com/sonic-net/sonic-pins) | Google's P4-based network stack support (P4 Integrated Network Stack, PINS). More information can be found on the [PINS website][SONiCPINS] |
| [sonic-stp](https://github.com/sonic-net/sonic-stp) | STP (Spanning Tree Protocol) support |
| [sonic-ztp](https://github.com/sonic-net/sonic-ztp) | [Zero Touch Provisioning][SONiCZTP] |
| [DASH](https://github.com/sonic-net/DASH) | [Disaggregated API for SONiC Hosts][SONiCDASH] |
| [sonic-host-services](https://github.com/sonic-net/sonic-host-services) | Services running on the host, providing support to services in containers via dbus, such as saving and reloading configurations, saving dumps, etc., similar to a host broker |
| [sonic-fips](https://github.com/sonic-net/sonic-fips) | FIPS (Federal Information Processing Standards) support, containing various patch files added to support FIPS standards |
| [sonic-wpa-supplicant](https://github.com/sonic-net/sonic-wpa-supplicant) | Support for various wireless network protocols |

## Tooling Repository: `sonic-utilities`

<https://github.com/sonic-net/sonic-utilities>

This repository contains all the command-line tools for SONiC:

- `config`, `show`, `clear` directories: These are the implementations of the three main SONiC CLI commands. Note that the specific command implementations may not necessarily be in these directories; many commands are implemented by calling other commands, with these directories providing an entry point.
- `scripts`, `sfputil`, `psuutil`, `pcieutil`, `fwutil`, `ssdutil`, `acl_loader` directories: These directories provide many tool commands, but most are not directly used by users; instead, they are called by commands in the `config`, `show`, and `clear` directories. For example, the `show platform fan` command is implemented by calling the `fanshow` command in the `scripts` directory.
- `utilities_common`, `flow_counter_util`, `syslog_util` directories: Similar to the above, but they provide base classes that can be directly imported and called in Python.
- There are also many other commands: `fdbutil`, `pddf_fanutil`, `pddf_ledutil`, `pddf_psuutil`, `pddf_thermalutil`, etc., used to view and control the status of various modules.
- `connect` and `consutil` directories: Commands in these directories are used to connect to and manage other SONiC devices.
- `crm` directory: Used to configure and view [CRM (Critical Resource Monitoring)][SONiCCRM] in SONiC. This command is not included in the `config` and `show` commands, so users can use it directly.
- `pfc` directory: Used to configure and view PFC (Priority-based Flow Control) in SONiC.
- `pfcwd` directory: Used to configure and view [PFC Watch Dog][SONiCPFCWD] in SONiC, such as starting, stopping, modifying polling intervals, and more.

## Kernel Patches: sonic-linux-kernel

<https://github.com/sonic-net/sonic-linux-kernel>

Although SONiC is based on Debian, the default Debian kernel may not necessarily run SONiC, such as certain modules not being enabled by default or issues with older drivers. Therefore, SONiC requires some modifications to the Linux kernel. This repository is used to store all the kernel patches.

# References

1. [SONiC Architecture][SONiCArch]
2. [SONiC Source Repositories][SONiCRepo]
3. [SONiC Management Framework][SONiCMgmtFramework]
4. [SAI API][SAIAPI]
5. [SONiC Critical Resource Monitoring][SONiCCRM]
6. [SONiC Zero Touch Provisioning][SONiCZTP]
7. [SONiC Critical Resource Monitoring][SONiCCRM]
8. [SONiC P4 Integrated Network Stack][SONiCPINS]
9. [SONiC Disaggregated API for Switch Hosts][SONiCDash]
10. [SAI spec for OCP][SAISpec]
11. [PFC Watchdog][SONiCPFCWD]

[SONiCIntro]: /posts/sonic-1-intro/
[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCMgmtFramework]: https://github.com/sonic-net/SONiC/blob/master/doc/mgmt/Management%20Framework.md
[SAIAPI]: https://github.com/opencomputeproject/SAI/wiki/SAI-APIs
[SONiCRepo]: https://github.com/sonic-net/SONiC/blob/master/sourcecode.md
[SONiCSAIRedis]: https://github.com/sonic-net/sonic-sairedis/
[SONiCGitHub]: https://github.com/sonic-net
[SONiCCRM]: https://github.com/sonic-net/SONiC/wiki/Critical-Resource-Monitoring-High-Level-Design
[SONiCPINS]: https://opennetworking.org/pins/
[SONiCZTP]: https://github.com/sonic-net/SONiC/blob/master/doc/ztp/ztp.md
[SONiCDASH]: https://github.com/sonic-net/DASH/blob/main/documentation/general/dash-high-level-design.md
[SAISpec]: https://www.opencompute.org/documents/switch-abstraction-interface-ocp-specification-v0-2-pdf
[SONiCPFCWD]: https://github.com/sonic-net/SONiC/wiki/PFC-Watchdog