# Service Layer - Orch

Finally, to make it more convenient for building services, SONiC provides another layer of abstraction on top of the communication layer, offering a base class for services: [Orch](https://github.com/sonic-net/sonic-swss/blob/master/src/orchagent/orch.h).

With all the lower layers, adding message communication support in Orch is relatively straightforward. The main class diagram is shown below:

![](assets/chapter-4/orch.png)

```admonish note
Note: Since this layer is part of the service layer, the code lives in the sonic-swss repository, not in sonic-swss-common. In addition to message communication, this class also provides many other utility functions related to service implementation (for example, log files, etc.).
```

We can see that Orch mainly wraps `SubscriberStateTable` and `ConsumerStateTable` to simplify and unify the message subscription. The core code is very simple and creates different Consumers based on the database type:

```cpp
void Orch::addConsumer(DBConnector *db, string tableName, int pri)
{
    if (db->getDbId() == CONFIG_DB || db->getDbId() == STATE_DB || db->getDbId() == CHASSIS_APP_DB) {
        addExecutor(
            new Consumer(
                new SubscriberStateTable(db, tableName, TableConsumable::DEFAULT_POP_BATCH_SIZE, pri),
                this,
                tableName));
    } else {
        addExecutor(
            new Consumer(
                new ConsumerStateTable(db, tableName, gBatchSize, pri),
                this,
                tableName));
    }
}
```

# References

1. [SONiC Architecture][SONiCArch]  
2. [Github repo: sonic-swss][SONiCSWSS]  
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common