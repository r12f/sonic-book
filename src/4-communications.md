# Communication

There are three main communication mechanisms in SONiC: communication using kernel, Redis-based inter-service communication, and ZMQ-based inter-service communication.

- There are two main methods for communication using kernel: command line calls and Netlink messages.
- Redis-based inter-service communication: There are 4 different communication channel based on Redis - SubscriberStateTable, NotificationProducer/Consumer, Producer/ConsumerTable, and Producer/ConsumerStateTable. Although they are all based on Redis, their use case can be very different.
- ZMQ-based inter-service communication: This communication mechanism is currently only used in the communication between `orchagent` and `syncd`.

```admonish note
Although most communication mechanisms support multi-consumer PubSub mode, please note: in SONiC, majority of communication (except some config table or state table via SubscriberStateTable) is point-to-point, meaning one producer will only send the message to one consumer. It is very rare to have a situation where one producer sending data to multiple consumers!

Channels like Producer/ConsumerStateTable essentually only support point-to-point communication. If multiple consumers appear, the message will only be delivered to one of the customers, causing all other consumer missing updates.
```

The implementation of all these basic communication mechanisms is in the `common` directory of the [sonic-swss-common][SONiCSWSSCommon] repo. Additionally, to facilitate the use of various services, SONiC has build a wrapper layer called Orch in [sonic-swss][SONiCSWSS], which helps simplify the upper-layer services.

In this chapter, we will dive into the implementation of these communication mechanisms!

# References

1. [SONiC Architecture][SONiCArch]
2. [Github repo: sonic-swss][SONiCSWSS]
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common