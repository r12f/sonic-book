# 通信机制

SONiC中主要的通信机制有三种：与内核的通信，基于Redis和基于ZMQ的服务间的通信。

- 与内核通信主要有两种方法：命令行调用和Netlink消息。
- 基于Redis的服务间通信主要有四种方法：SubscriberStateTable，NotificationProducer/Consumer，Producer/ConsumerTable，Producer/ConsumerStateTable。虽然它们都是基于Redis的，但是它们解决的问题和方法却非常不同。
- 基于ZMQ的服务间通信：现在只在`orchagent`和`syncd`的通信中使用了这种通信机制。

```admonish note
虽然大部分的通信机制都支持多消费者的PubSub的模式，但是请特别注意：在SONiC中，所有的通信都是点对点的，即一个生产者对应一个消费者，绝对不会出现一个生产者对应多个消费者的情况！

一旦多消费者出现，那么一个消息的处理逻辑将可能发生在多个进程中，这将导致很大的问题，因为对于任何一种特定的消息，SONiC中只有一个地方来处理，所以这会导致部分消息不可避免的出错或者丢失。
```

所有这些基础的通信机制的实现都在[sonic-swss-common][SONiCSWSSCommon]这个repo中的`common`目录下。另外在其之上，为了方便各个服务使用，SONiC还在[sonic-swss][SONiCSWSS]中封装了一层Orch，将常用的表放在其中。

这一章，我们就主要来看看这些通信机制的实现吧！

# 参考资料

1. [SONiC Architecture][SONiCArch]
2. [Github repo: sonic-swss][SONiCSWSS]
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common