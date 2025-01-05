# Netlink

Netlinkis the message-based communication mechanism provided by Linux kernel and used between the kernel and user-space processes. It is implemented via socket and custom protocol families. It can be used to deliver various types of kernel messages, including network device status, routing table updates, firewall rule changes, and system resource usage. SONiC's `*sync` services heavily utilize Netlink to monitor changes of network devices in the system, synchronize the latest status to Redis, and notify other services to make corresponding updates.

The main implementation of netlink communication channel is done by these files:

- [common/netmsg.*](https://github.com/sonic-net/sonic-swss-common/blob/master/common/netmsg.h)
- [common/netlink.*](https://github.com/sonic-net/sonic-swss-common/blob/master/common/netlink.h)
- [common/netdispatcher.*](https://github.com/sonic-net/sonic-swss-common/blob/master/common/netdispatcher.h).

The class diagram is as follows:

![](assets/chapter-4/netlink.png)

In this diagram:

- **Netlink**: Wraps the netlink socket interface and provides an interface for sending netlink messages and a callback for receiving messages.
- **NetDispatcher**: A singleton that provides an interface for registering handlers. When a raw netlink message is received, it calls NetDispatcher to parse them into `nl_object` objects and then dispatches them to the corresponding handler based on the message type.
- **NetMsg**: The base class for netlink message handlers, which only provides the `onMsg` interface without a default implementation.

For example, when `portsyncd` starts, it creates a `Netlink` object to listen for link-related status changes and implements the `NetMsg` interface to handle the link messages. The specific implementation is as follows:

```cpp
// File: sonic-swss - portsyncd/portsyncd.cpp
int main(int argc, char **argv)
{
    // ...

    // Create Netlink object to listen to link messages
    NetLink netlink;
    netlink.registerGroup(RTNLGRP_LINK);

    // Here SONiC requests a full dump of the current state to get the status of all links
    netlink.dumpRequest(RTM_GETLINK);
    cout << "Listen to link messages..." << endl;
    // ...

    // Register handler for link messages
    LinkSync sync(&appl_db, &state_db);
    NetDispatcher::getInstance().registerMessageHandler(RTM_NEWLINK, &sync);
    NetDispatcher::getInstance().registerMessageHandler(RTM_DELLINK, &sync);

    // ...
}
```

The `LinkSync` class above is an implementation of `NetMsg`, providing the `onMsg` interface for handling link messages:

```cpp
// File: sonic-swss - portsyncd/linksync.h
class LinkSync : public NetMsg
{
public:
    LinkSync(DBConnector *appl_db, DBConnector *state_db);

    // NetMsg interface
    virtual void onMsg(int nlmsg_type, struct nl_object *obj);

    // ...
};

// File: sonic-swss - portsyncd/linksync.cpp
void LinkSync::onMsg(int nlmsg_type, struct nl_object *obj)
{
    // ...

    // Write link state to Redis DB
    FieldValueTuple fv("oper_status", oper ? "up" : "down");
    vector<FieldValueTuple> fvs;
    fvs.push_back(fv);
    m_stateMgmtPortTable.set(key, fvs);
    // ...
}
```

# References

1. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common