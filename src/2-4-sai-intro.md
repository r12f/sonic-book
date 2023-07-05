# SAI

SAI（Switch Abstraction Interface，交换机抽象接口）是SONiC的基石，正因为有了它，SONiC才能支持多种硬件平台。我们在[这个SAI API的文档][SAIAPI]中，可以看到它定义的所有接口。

[在核心容器一节中我们提到，SAI运行在`syncd`容器中](./2-3-key-containers.html)。不过和其他组件不同，它并不是一个服务，而是一组公共的头文件和动态链接库（.so）。其中，所有的抽象接口都以c语言头文件的方式定义在了[OCP的SAI仓库][OCPSAI]中，而.so文件则由各个硬件厂商提供，用于实现SAI的接口。

## SAI接口

为了有一个更加直观的理解，我们拿一小部分代码来展示一下SAI的接口定义和初始化的方法，如下：

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

其中，`sai_apis_t`结构体是SAI所有模块的接口的集合，其中每个成员都是一个特定模块的接口列表的指针。我们用`sai_switch_api_t`来举例，它定义了SAI Switch模块的所有接口，我们在`inc/saiswitch.h`中可以看到它的定义。同样的，我们在`inc/saiport.h`中可以看到SAI Port模块的接口定义。

## SAI初始化

SAI的初始化其实就是想办法获取上面这些函数指针，这样我们就可以通过SAI的接口来操作ASIC了。

参与SAI初始化的主要函数有两个，他们都定义在`inc/sai.h`中：

- `sai_api_initialize`：初始化SAI
- `sai_api_query`：传入SAI的API的类型，获取对应的接口列表

虽然大部分厂商的SAI实现是闭源的，但是mellanox却开源了自己的SAI实现，所以这里我们可以借助其更加深入的理解SAI是如何工作的。

比如，`sai_api_initialize`函数其实就是简单的设置设置两个全局变量，然后返回`SAI_STATUS_SUCCESS`：

```cpp
// File: platform/mellanox/mlnx-sai/SAI-Implementation/mlnx_sai/src/mlnx_sai_interfacequery.c
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

初始化完成后，我们就可以使用`sai_api_query`函数，通过传入API的类型来查询对应的接口列表，而每一个接口列表其实都是一个全局变量：

```cpp
// File: platform/mellanox/mlnx-sai/SAI-Implementation/mlnx_sai/src/mlnx_sai_interfacequery.c
sai_status_t sai_api_query(_In_ sai_api_t sai_api_id, _Out_ void** api_method_table)
{
    if (!g_initialized) {
        return SAI_STATUS_UNINITIALIZED;
    }
    ...

    return sai_api_query_eth(sai_api_id, api_method_table);
}

// File: platform/mellanox/mlnx-sai/SAI-Implementation/mlnx_sai/src/mlnx_sai_interfacequery_eth.c
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

// File: platform/mellanox/mlnx-sai/SAI-Implementation/mlnx_sai/src/mlnx_sai_bridge.c
const sai_bridge_api_t mlnx_bridge_api = {
    mlnx_create_bridge,
    mlnx_remove_bridge,
    mlnx_set_bridge_attribute,
    mlnx_get_bridge_attribute,
    ...
};


// File: platform/mellanox/mlnx-sai/SAI-Implementation/mlnx_sai/src/mlnx_sai_switch.c
const sai_switch_api_t mlnx_switch_api = {
    mlnx_create_switch,
    mlnx_remove_switch,
    mlnx_set_switch_attribute,
    mlnx_get_switch_attribute,
    ...
};
```

## SAI的使用

在`syncd`容器中，SONiC会在启动时启动`syncd`服务，而`syncd`服务会加载当前系统中的SAI组件。这个组件由各个厂商提供，它们会根据自己的硬件平台来实现上面展现的SAI的接口，从而让SONiC使用统一的上层逻辑来控制多种不同的硬件平台。

我们可以通过`ps`, `ls`和`nm`命令来简单的对这个进行验证：

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

# 参考资料

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