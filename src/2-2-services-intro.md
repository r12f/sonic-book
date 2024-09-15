
# Introduction to Services and Workflows

There are many services (daemon processes) in SONiC, around twenty to thirty. They start with the switch and keep running until the switch is shut down. If we want to quickly understand how SONiC works, diving into each service one by one is obviously not a good option. Therefore, it is better to categorize these services and control flows on high level to help us build a big picture.

```admonish note
We will not delve into any specific service here. Instead, we will first look at the overall structure of services in SONiC to help us build a comprehensive understanding. For specific services, we will introduce its workflows in the workflow chapter. For detailed information, we can also refer to the design documents related to each service.
```

## Service Categories

Generally speaking, the services in SONiC can be divided into the following categories: `*syncd`, `*mgrd`, feature implementations, `orchagent`, and `syncd`.

### `*syncd` Services

These services have names ending with `syncd`. They perform similar tasks: synchronizing hardware states to Redis, usually into APPL_DB or STATE_DB.

For example, `portsyncd` listens to netlink events and synchronizes the status of all ports in the switch to STATE_DB, while `natsyncd` listens to netlink events and synchronizes all NAT statuses in the switch to APPL_DB.

### `*mgrd` Services

These services have names ending with `mgrd`. As the name suggests, these are "Manager" services responsible for configuring various hardware, opposite to `*syncd`. Their logic mainly consists of two parts:

1. **Configuration Deployment**: Responsible for reading configuration files and listening to configuration and state changes in Redis (mainly CONFIG_DB, APPL_DB, and STATE_DB), then pushing these changes to the switch hardware. The method of pushing varies depending on the target, either by updating APPL_DB and publishing update messages or directly calling Linux command lines to modify the system. For example, `nbrmgr` listens to changes in CONFIG_DB, APPL_DB, and STATE_DB for neighbors and modifies neighbors and routes using netlink and command lines, while `intfmgr` not only calls command lines but also updates some states to APPL_DB.
2. **State Synchronization**: For services that need reconciliation, `*mgrd` also listens to state changes in STATE_DB. If it finds that the hardware state is inconsistent with the expected state, it will re-initiate the configuration process to set the hardware state to the expected state. These state changes in STATE_DB are usually pushed by `*syncd` services. For example, `intfmgr` listens to port up/down status and MTU changes pushed by `portsyncd` in STATE_DB. If it finds inconsistencies with the expected state stored in its memory, it will re-deploy the configuration.

### `orchagent` Service

This is the most important service in SONiC. Unlike other services that are responsible for one or two specific functions, `orchagent`, as the orchestrator of the switch ASIC state, checks all states from `*syncd` services in the database, integrates them, and deploys them to ASIC_DB, which is used to store the switch ASIC configuration. These states are eventually received by `syncd`, which calls the SAI API through the SAI implementation and ASIC SDK provided by various vendors to interact with the ASIC, ultimately deploying the configuration to the switch hardware.

### Feature Implementation Services

Some features are not implemented by the OS itself but by specific processes, such as BGP or some external-facing interfaces. These services often have names ending with `d`, indicating daemon, such as `bgpd`, `lldpd`, `snmpd`, `teamd`, etc., or simply the name of the feature, such as `fancontrol`.

### `syncd` Service

The `syncd` service is downstream of `orchagent`. Although its name is `syncd`, it shoulders the work of both `*mgrd` and `*syncd` for the ASIC.

- First, as `*mgrd`, it listens to state changes in ASIC_DB. Once detected, it retrieves the new state and calls the SAI API to deploy the configuration to the switch hardware.
- Then, as `*syncd`, if the ASIC sends any notifications to SONiC, it will send these notifications to Redis as messages, allowing `orchagent` and `*mgrd` services to obtain these changes and process them. The types of these notifications can be found in [SwitchNotifications.h][SAISwitchNotify].

## Control Flow Between Services

With service categories, we can now better understand the services in SONiC. To get started, it is crucial to understand the control flow between services. Based on the above categories, we can divide the main control flows into two categories: configuration deployment and state synchronization.

### Configuration Deployment

The configuration deployment process generally follows these steps:

1. **Modify Configuration**: Users can modify configurations through CLI or REST API. These configurations are written to CONFIG_DB and send update notifications through Redis. Alternatively, external programs can modify configurations through specific interfaces, such as the BGP API. These configurations are sent to `*mgrd` services through internal TCP sockets.
2. **`*mgrd` Deploys Configuration**: Services listen to configuration changes in CONFIG_DB and then push these configurations to the switch hardware. There are two main scenarios (which can coexist):
   1. **Direct Deployment**:
      1. `*mgrd` services directly call Linux command lines or modify system configurations through netlink.
      2. `*syncd` services listen to system configuration changes through netlink or other methods and push these changes to STATE_DB or APPL_DB.
      3. `*mgrd` services listen to configuration changes in STATE_DB or APPL_DB, compare these configurations with those stored in their memory, and if inconsistencies are found, they re-call command lines or netlink to modify system configurations until they are consistent.
   2. **Indirect Deployment**:
      1. `*mgrd` pushes states to APPL_DB and sends update notifications through Redis.
      2. `orchagent` listens to configuration changes, calculates the state the ASIC should achieve based on all related states, and deploys it to ASIC_DB.
      3. `syncd` listens to changes in ASIC_DB and updates the switch ASIC configuration through the unified SAI API interface by calling the ASIC Driver.

Configuration initialization is similar to configuration deployment but involves reading configuration files when services start, which will not be expanded here.

### State Synchronization

If situations arise, such as a port failure or changes in the ASIC state, state updates and synchronization are needed. The process generally follows these steps:

1. **Detect State Changes**: These state changes mainly come from `*syncd` services (netlink, etc.) and `syncd` services ([SAI Switch Notification][SAISwitchNotify]). After detecting changes, these services send them to STATE_DB or APPL_DB.
2. **Process State Changes**: `orchagent` and `*mgrd` services listen to these changes, process them, and re-deploy new configurations to the system through command lines and netlink or to ASIC_DB for `syncd` services to update the ASIC again.

### Specific Examples

The official SONiC documentation provides several typical examples of control flow. Interested readers can refer to [SONiC Subsystem Interactions](https://github.com/sonic-net/SONiC/wiki/Architecture#sonic-subsystems-interactions). In the workflow chapter, we will also expand on some very common workflows.

# References

1. [SONiC Architecture][SONiCArch]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SAISwitchNotify]: https://github.com/sonic-net/sonic-sairedis/blob/master/syncd/SwitchNotifications.h
