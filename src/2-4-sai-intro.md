# SAI

SAI (Switch Abstraction Interface) is the cornerstone of SONiC, while enables it to support multiple hardware platforms. In [this SAI API document][SAIAPI], we can see all the interfaces it defines.

[In the core container section, we mentioned that SAI runs in the `syncd` container](./2-3-key-containers.html). However, unlike other components, it is not a service but a set of common header files and dynamic link libraries (.so). All abstract interfaces are defined as C language header files in the [OCP SAI repository][OCPSAI], and the hardware vendors provides the .so files that implement the SAI interfaces.

## SAI Interface

To make things more intuitive, let's take a small portion of the code to show how SAI interfaces look like and how it works, as follows:

```cpp
// File: meta/saimetadata.h
typedef struct _sai_apis_t {
    sai_switch_api_t* switch_api;
    sai_port_api_t* port_api;
    ...
} sai_apis_t;

// File: inc/saiswitch.h
typedef struct _sai_switch_api_t
{
    sai_create_switch_fn                   create_switch;
    sai_remove_switch_fn                   remove_switch;
    sai_set_switch_attribute_fn            set_switch_attribute;
    sai_get_switch_attribute_fn            get_switch_attribute;
    ...
} sai_switch_api_t;

// File: inc/saiport.h
typedef struct _sai_port_api_t
{
    sai_create_port_fn                     create_port;
    sai_remove_port_fn                     remove_port;
    sai_set_port_attribute_fn              set_port_attribute;
    sai_get_port_attribute_fn              get_port_attribute;
    ...
} sai_port_api_t;
```

The `sai_apis_t` structure is a collection of interfaces for all SAI modules, with each member being a pointer to a specific module's interface list. For example, `sai_switch_api_t` defines all the interfaces for the SAI Switch module, and its definition can be found in `inc/saiswitch.h`. Similarly, the interface definitions for the SAI Port module can be found in `inc/saiport.h`.

## SAI Initialization

SAI initialization is essentially about obtaining these function pointers so that we can operate the ASIC through the SAI interfaces.

The main functions involved in SAI initialization are defined in `inc/sai.h`:

- `sai_api_initialize`: Initialize SAI
- `sai_api_query`: Pass in the type of SAI API to get the corresponding interface list

Although most vendors' SAI implementations are closed-source, Mellanox has open-sourced its SAI implementation, allowing us to gain a deeper understanding of how SAI works.

For example, the `sai_api_initialize` function simply sets two global variables and returns `SAI_STATUS_SUCCESS`:

```cpp
// File: https://github.com/Mellanox/SAI-Implementation/blob/master/mlnx_sai/src/mlnx_sai_interfacequery.c
sai_status_t sai_api_initialize(_In_ uint64_t flags, _In_ const sai_service_method_table_t* services)
{
    if (g_initialized) {
        return SAI_STATUS_FAILURE;
    }
    // Validate parameters here (code omitted)

    memcpy(&g_mlnx_services, services, sizeof(g_mlnx_services));
    g_initialized = true;
    return SAI_STATUS_SUCCESS;
}
```

After initialization, we can use the `sai_api_query` function to query the corresponding interface list by passing in the type of API, where each interface list is actually a global variable:

```cpp
// File: https://github.com/Mellanox/SAI-Implementation/blob/master/mlnx_sai/src/mlnx_sai_interfacequery.c
sai_status_t sai_api_query(_In_ sai_api_t sai_api_id, _Out_ void** api_method_table)
{
    if (!g_initialized) {
        return SAI_STATUS_UNINITIALIZED;
    }
    ...

    return sai_api_query_eth(sai_api_id, api_method_table);
}

// File: https://github.com/Mellanox/SAI-Implementation/blob/master/mlnx_sai/src/mlnx_sai_interfacequery_eth.c
sai_status_t sai_api_query_eth(_In_ sai_api_t sai_api_id, _Out_ void** api_method_table)
{
    switch (sai_api_id) {
    case SAI_API_BRIDGE:
        *(const sai_bridge_api_t**)api_method_table = &mlnx_bridge_api;
        return SAI_STATUS_SUCCESS;
    case SAI_API_SWITCH:
        *(const sai_switch_api_t**)api_method_table = &mlnx_switch_api;
        return SAI_STATUS_SUCCESS;
    ...
    default:
        if (sai_api_id >= (sai_api_t)SAI_API_EXTENSIONS_RANGE_END) {
            return SAI_STATUS_INVALID_PARAMETER;
        } else {
            return SAI_STATUS_NOT_IMPLEMENTED;
        }
    }
}

// File: https://github.com/Mellanox/SAI-Implementation/blob/master/mlnx_sai/src/mlnx_sai_bridge.c
const sai_bridge_api_t mlnx_bridge_api = {
    mlnx_create_bridge,
    mlnx_remove_bridge,
    mlnx_set_bridge_attribute,
    mlnx_get_bridge_attribute,
    ...
};


// File: https://github.com/Mellanox/SAI-Implementation/blob/master/mlnx_sai/src/mlnx_sai_switch.c
const sai_switch_api_t mlnx_switch_api = {
    mlnx_create_switch,
    mlnx_remove_switch,
    mlnx_set_switch_attribute,
    mlnx_get_switch_attribute,
    ...
};
```

## Using SAI

In the `syncd` container, SONiC starts the `syncd` service at startup, which loads the SAI component present in the system. This component is provided by various vendors, who implement the SAI interfaces based on their hardware platforms, allowing SONiC to use a unified upper-layer logic to control various hardware platforms.

We can verify this using the `ps`, `ls`, and `nm` commands:

```bash
# Enter into syncd container
admin@sonic:~$ docker exec -it syncd bash

# List all processes. We will only see syncd process here.
root@sonic:/# ps aux
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
...
root          21  0.0  0.0  87708  1532 pts/0    Sl   16:20   0:00 /usr/bin/dsserve /usr/bin/syncd --diag -u -s -p /etc/sai.d/sai.profile -b /tmp/break_before_make_objects
root          33 11.1 15.0 2724396 602532 pts/0  Sl   16:20  36:30 /usr/bin/syncd --diag -u -s -p /etc/sai.d/sai.profile -b /tmp/break_before_make_objects
...

# Find all libsai*.so.* files.
root@sonic:/# find / -name libsai*.so.*
/usr/lib/x86_64-linux-gnu/libsaimeta.so.0
/usr/lib/x86_64-linux-gnu/libsaimeta.so.0.0.0
/usr/lib/x86_64-linux-gnu/libsaimetadata.so.0.0.0
/usr/lib/x86_64-linux-gnu/libsairedis.so.0.0.0
/usr/lib/x86_64-linux-gnu/libsairedis.so.0
/usr/lib/x86_64-linux-gnu/libsaimetadata.so.0
/usr/lib/libsai.so.1
/usr/lib/libsai.so.1.0

# Copy the file out of switch and check libsai.so on your own dev machine.
# We will see the most important SAI export functions here.
$ nm -C -D ./libsai.so.1.0 > ./sai-exports.txt
$ vim sai-exports.txt
...
0000000006581ae0 T sai_api_initialize
0000000006582700 T sai_api_query
0000000006581da0 T sai_api_uninitialize
...
```

# References

1. [SONiC Architecture][SONiCArch]
2. [SAI API][SAIAPI]
3. [Forwarding Metamorphosis: Fast Programmable Match-Action Processing in Hardware for SDN][PISA]
4. [Github: sonic-net/sonic-sairedis][SONiCSAIRedis]
5. [Github: opencomputeproject/SAI][OCPSAI]
6. [Arista 7050QX Series 10/40G Data Center Switches Data Sheet][Arista7050QX]
7. [Github repo: Nvidia (Mellanox) SAI implementation][MnlxSAI]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[PISA]: http://yuba.stanford.edu/~grg/docs/sdn-chip-sigcomm-2013.pdf
[SAIAPI]: https://github.com/opencomputeproject/SAI/wiki/SAI-APIs
[SONiCRepo]: https://github.com/sonic-net/SONiC/blob/master/sourcecode.md
[SONiCSAIRedis]: https://github.com/sonic-net/sonic-sairedis/
[OCPSAI]: https://github.com/opencomputeproject/SAI
[Arista7050QX]: https://www.arista.com/assets/data/pdf/Datasheets/7050QX-32_32S_Datasheet_S.pdf
[MnlxSAI]: https://github.com/Mellanox/SAI-Implementation/tree/master