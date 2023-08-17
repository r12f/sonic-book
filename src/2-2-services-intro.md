# 服务与工作流简介

SONiC里面的服务（常驻进程）非常的多，有二三十种，它们会在随着交换机启动而启动，并一直保持运行，直到交换机关机。如果我们想快速掌握SONiC，一个一个服务的去了解，会很容易陷入细节的泥潭，所以，我们最好把这些服务和控制流进行一个大的分类，以帮助我们建立一个宏观的概念。

```admonish note
我们这里不会深入到某一个具体的服务中去，而是先从整体上来看看SONiC中的服务的结构，帮助我们建立一个整体的认识。关于具体的服务，我们会在工作流一章中，对常用的工作流进行介绍，而关于详细的技术细节，大家也可以查阅每个服务相关的设计文档。
```

## 服务分类

总体而言，SONiC中的服务可以分为以下几类：`*syncd`, `*mgrd`，feature实现，`orchagent`和`syncd`。

### `*syncd`服务

这类服务名字中都以`syncd`结尾。它们做的事情都很类似：它们负责将硬件状态同步到Redis中，一般目标都以APPL_DB或者STATE_DB为主。

比如，`portsyncd`就是通过监听netlink的事件，将交换机中所有Port的状态同步到STATE_DB中，而`natsyncd`则是监听netlink的事件，将交换机中所有的NAT状态同步到APPL_DB中。

### `*mgrd`服务

这类服务名字中都以`mgrd`结尾。顾名思义，这些服务是所谓的“Manager”服务，也就是说它们负责各个硬件的配置，和`*syncd`完全相反。它们的逻辑主要有两个部分：

1. **配置下发**：负责读取配置文件和监听Redis中的配置和状态改变（主要是CONFIG_DB，APPL_DB和STATE_DB），然后将这些修改推送到交换机硬件中去。推送的方法有多种，取决于更新的目标是什么，可以通过更新APPL_DB并发布更新消息，或者是直接调用linux下的命令行，对系统进行修改。比如：`nbrmgr`就是监听CONFIG_DB，APPL_DB和STATE_DB中neighbor的变化，并调用netlink和command line来对neighbor和route进行修改，而`intfmgr`除了调用command line还会将一些状态更新到APPL_DB中去。
2. **状态同步**：对于需要Reconcile的服务，`*mgrd`还会监听STATE_DB中的状态变化，如果发现硬件状态和当前期望状态不一致，就会重新发起配置流程，将硬件状态设置为期望状态。这些STATE_DB中的状态变化一般都是`*syncd`服务推送的。比如：`intfmgr`就会监听STATE_DB中，由`portsyncd`推送的，端口的Up/Down状态和MTU变化，一旦发现和其内存中保存的期望状态不一致，就会重新下发配置。

### 功能实现服务

有一些功能并不是依靠OS本身来完成的，而是由一些特定的进程来实现的，比如BGP，或者一些外部接口。这些服务名字中经常以`d`结尾，表示deamon，比如：`bgpd`，`lldpd`，`snmpd`，`teamd`等，或者干脆就是这个功能的名字，比如：`fancontrol`。

### `orchagent`服务

这个是SONiC中最重要的一个服务，不像其他的服务只负责一两个特定的功能，`orchagent`作为交换机ASIC状态的编排者（orchestrator），会检查数据库中所有来自`*syncd`服务的状态，整合起来并下发给用于保存交换机ASIC配置的数据库：ASIC_DB。这些状态最后会被`syncd`接收，并调用SAI API经过各个厂商提供的SAI实现和ASIC SDK和ASIC进行交互，最终将配置下发到交换机硬件中。

### `syncd`服务

`syncd`服务是`orchagent`的下游，它虽然名字叫`syncd`，但是它却同时肩负着ASIC的`*mgrd`和`*syncd`的工作。

- 首先，作为`*mgrd`，它会监听ASIC_DB的状态变化，一旦发现，就会获取其新的状态并调用SAI API，将配置下发到交换机硬件中。
- 然后，作为`*syncd`，如果ASIC发送了任何的通知给SONiC，它也会将这些通知通过消息的方式发送到Redis中，以便`orchagent`和`*mgrd`服务获取到这些变化，并进行处理。这些通知的类型我们可以在[SwitchNotifications.h][SAISwitchNotify]中找到。

## 服务间控制流分类

有了这些分类，我们就可以更加清晰的来理解SONiC中的服务了，而其中非常重要的就是理解服务之间的控制流。有了上面的分类，我们这里也可以把主要的控制流有分为两类：配置下发和状态同步。

### 配置下发

配置下发的流程一般是这样的：

1. **修改配置**：用户可以通过CLI或者REST API修改配置，这些配置会被写入到CONFIG_DB中并通过Redis发送更新通知。或者外部程序可以通过特定的接口，比如BGP的API，来修改配置，这种配置会通过内部的TCP Socket发送给`*mgrd`服务。
2. **`*mgrd`下发配置**：服务监听到CONFIG_DB中的配置变化，然后将这些配置推送到交换机硬件中。这里由两种主要情况（并且可以同时存在）：
   1. **直接下发**：
      1. `*mgrd`服务直接调用linux下的命令行，或者是通过netlink来修改系统配置
      2. `*syncd`服务会通过netlink或者其他方式监听到系统配置的变化，并将这些变化推送到STATE_DB或者APPL_DB中。
      3. `*mgrd`服务监听到STATE_DB或者APPL_DB中的配置变化，然后将这些配置和其内存中存储的配置进行比较，如果发现不一致，就会重新调用命令行或者netlink来修改系统配置，直到它们一致为止。
   2. **间接下发**：
      1. `*mgrd`将状态推送到APPL_DB并通过Redis发送更新通知。
      2. `orchagent`服务监听到配置变化，然后根据所有相关的状态，计算出此时ASIC应该达到的状态，并下发到ASIC_DB中。
      3. `syncd`服务监听到ASIC_DB的变化，然后将这些新的配置通过统一的SAI API接口，调用ASIC Driver更新交换机ASIC中的配置。

配置初始化和配置下发类似，不过是在服务启动的时候读取配置文件，这里就不展开了。

### 状态同步

如果这个时候，出现了一些情况，比如网口坏了，ASIC中的状态变了等等，这个时候我们就需要进行状态更新和同步了。这个流程一般是这样的：

1. **检测状态变化**：这个状态变化主要来源于`*syncd`服务（netlink等等）和`syncd`服务（[SAI Switch Notification][SAISwitchNotify]），这些服务在检测到变化后，会将它们发送给STATE_DB或者APPL_DB。
2. **处理状态变化**：`orchagent`和`*mgrd`服务会监听到这些变化，然后开始处理，将新的配置重新通过命令行和netlink下发给系统，或者下发到ASIC_DB中，让`syncd`服务再次对ASIC进行更新。

### 具体例子

SONiC的官方文档中给出了几个典型的控制流流转的例子，这里就不过多的展开了，有兴趣的朋友可以去这里看看：[SONiC Subsystem Interactions](https://github.com/sonic-net/SONiC/wiki/Architecture#sonic-subsystems-interactions)。我们在后面工作流一章中，也会选择一些非常常用的工作流进行展开。


# 参考资料

1. [SONiC Architecture][SONiCArch]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SAISwitchNotify]: https://github.com/sonic-net/sonic-sairedis/blob/master/syncd/SwitchNotifications.h