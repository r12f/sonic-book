# 通信机制

SONiC中主要的通信机制有两种：与内核的通信和基于Redis的服务间的通信。

- 与内核通信主要有两种方法：命令行调用和Netlink消息。
- 而基于Redis的服务间通信主要有四种方法：SubscriberStateTable，NotificationProducer/Consumer，Producer/ConsumerTable，Producer/ConsumerStateTable。虽然它们都是基于Redis的，但是它们解决的问题和方法却非常不同。

所有这些基础的通信机制的实现都在[sonic-swss-common][SONiCSWSSCommon]这个repo中的`common`目录下。另外在其之上，为了方便各个服务使用，SONiC还在[sonic-swss][SONiCSWSS]中封装了一层Orch，将常用的表放在其中。

这一章，我们就主要来看看这些通信机制的实现吧！

# 参考资料

1. [SONiC Architecture][SONiCArch]
2. [Github repo: sonic-swss][SONiCSWSS]
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common