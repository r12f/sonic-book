# Redis Wrappers

## Redis Database Operation Layer

The first layer, which is also the lowest layer, is the Redis database operation layer. It wraps various basic commands, such as DB connection, command execution, event notification callback interfaces, etc. The specific class diagram is as follows:

![](assets/chapter-4/redis-ops.png)

Among them:

- **[RedisContext](https://github.com/sonic-net/sonic-swss-common/blob/master/common/dbconnector.h)**: Wraps and maintains the connection to Redis, and closes the connection when it is destroyed.
- **[DBConnector](https://github.com/sonic-net/sonic-swss-common/blob/master/common/dbconnector.h)**: Wraps all the underlying Redis commands used, such as `SET`, `GET`, `DEL`, etc.
- **[RedisTransactioner](https://github.com/sonic-net/sonic-swss-common/blob/master/common/redistran.h)**: Wraps Redis transaction operations, used to execute multiple commands in a transaction, such as `MULTI`, `EXEC`, etc.
- **[RedisPipeline](https://github.com/sonic-net/sonic-swss-common/blob/master/common/redispipeline.h)**: Wraps the hiredis redisAppendFormattedCommand API, providing an asynchronous interface for executing Redis commands similar to a queue (although most usage methods are still synchronous). It is also one of the few classes that wraps the `SCRIPT LOAD` command, used to load Lua scripts in Redis to implement stored procedures. Most classes in SONiC that need to execute Lua scripts will use this class for loading and calling.
- **[RedisSelect](https://github.com/sonic-net/sonic-swss-common/blob/master/common/redisselect.h)**: Implements the Selectable interface to support the epoll-based event notification mechanism (Event Polling). Mainly used to trigger epoll callbacks when we receive a reply from Redis (we will introduce this in more detail later).
- **[SonicDBConfig](https://github.com/sonic-net/sonic-swss-common/blob/master/common/dbconnector.h)**: This class is a "static class" that mainly implements the reading and parsing of the SONiC DB configuration file. Other database operation classes will use this class to obtain any configuration information if needed.

## Table Abstraction Layer

Above the Redis database operation layer is the table abstraction layer established by SONiC using the keys in Redis. Since the format of each Redis key is `<table-name><separator><key-name>`, SONiC needs to craft or parse it, when accessing the database. For more details on how the database is designed, please refer to [the database section for more information](/posts/sonic-2-key-components/#database).

The main class diagram of related classes is as follows:

![](assets/chapter-4/table-abstraction.png)

In this diagram, we have three key classes:

- **[TableBase](https://github.com/sonic-net/sonic-swss-common/blob/master/common/table.h)**: This class is the base class for all tables. It mainly wraps the basic information of the table, such as the table name, Redis key packaging, the name of the channel used for communication when each table is modified, etc.
- **[Table](https://github.com/sonic-net/sonic-swss-common/blob/master/common/table.h)**: This class wraps the CRUD operations for each table. It contains the table name and separator, so the final key can be constructed when called.
- **[ConsumerTableBase](https://github.com/sonic-net/sonic-swss-common/blob/master/common/consumertablebase.h)**: This class is the base class for various SubscriptionTables. It mainly wraps a simple queue and its pop operation (yes, only pop, no push, because it is for consumers only), for upper layer calls.

# References

1. [SONiC Architecture][SONiCArch]
2. [Github repo: sonic-swss][SONiCSWSS]
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common