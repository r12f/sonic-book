# ProducerTable / ConsumerTable

Although `NotificationProducer` and `NotificationConsumer` is straight-forward, but they are not suitable for passing large data. Therefore, SONiC provides another message-queue-based communication mechanism that works in similar way - [ProducerTable](https://github.com/sonic-net/sonic-swss-common/blob/master/common/producertable.h) and [ConsumerTable](https://github.com/sonic-net/sonic-swss-common/blob/master/common/consumertable.h).

This channel leverages the Redis list to pass the message. Unlike Notification, which has limited message capacity, it stores all the message data in a Redis list with a very slim custom messsage format. This solves the message size limitation in Notification. In SONiC, it is mainly used in FlexCounter, the `syncd` service, and `ASIC_DB`.

## Message format

In this channel, a message is a triplet (`Key`, `FieldValuePairs`, `Op`) and will be pushed into the Redis list (Key = `<table-name>_KEY_VALUE_OP_QUEUE`) as 3 list items:

- `Key` is table name and key (e.g., `SAI_OBJECT_TYPE_SWITCH:oid:0x21000000000000`).
- `FieldValuePairs` are the field that needs to be updated in the database and their values, which is serialized into a JSON string: `"[\"Field1\", \"Value1\", \"Field2\", \"Value2\", ...]"`.
- `Op` is the operation to be performed (e.g., Set, Get, Del, etc.)

Once the message is pushed into the Redis list, a notification will be published to a specific channel (Key = `<table-name>_CHANNEL`) with only a single character "G" as payload, indicating that there is a new message in the list.

So, when using this channel, we can imaging the actual data stored in the Redis:

- In the channel: `["G", "G", ...]`
- In the list: `["Key1", "FieldValuePairs1", "Op1", "Key2", "FieldValuePairs2", "Op2", ...]`

## Queue operations

Using this message format, `ProducerTable` and `ConsumerTable` provides two queue operations:

1. Enqueue: `ProducerTable` uses a Lua script to atomically write the message triplet into the Redis list and then publishes an update notification to a specific channel.
2. Pop: `ConsumerTable` also uses a Lua script to atomically read the message triplet from the message queue and writes the requested changes to the database during the read process.

```admonish note
**Note**: The atomicity of Lua scripts and MULTI/EXEC in Redis differs from the usual database ACID notion of Atomicity. Redis's atomicity is closer to Isolation in ACID: it ensures that no other command interleaves while a Lua script is running, but it does not guarantee that all commands in the script will successfully execute. For example, if the second command fails, the first one is still committed, and the subsequent commands are not executed. Refer to [\[5\]][RedisTx] and [\[6\]][RedisLuaAtomicity] for more details.
```

Its main class diagram is shown below. In ProducerTable, `m_shaEnqueue` and in ConsumerTable, `m_shaPop` are the two Lua scripts we mentioned. After they are loaded, you can call them atomically via `EVALSHA`:

![](assets/chapter-4/producer-consumer-table.png)

The core logic of ProducerTable is as follows, showing how values are packed into JSON and how `EVALSHA` is used to call Lua scripts:

```cpp
// File: sonic-swss-common - common/producertable.cpp
ProducerTable::ProducerTable(RedisPipeline *pipeline, const string &tableName, bool buffered)
    // ...
{
    string luaEnque =
        "redis.call('LPUSH', KEYS[1], ARGV[1], ARGV[2], ARGV[3]);"
        "redis.call('PUBLISH', KEYS[2], ARGV[4]);";

    m_shaEnque = m_pipe->loadRedisScript(luaEnque);
}

void ProducerTable::set(const string &key, const vector<FieldValueTuple> &values, const string &op, const string &prefix)
{
    enqueueDbChange(key, JSon::buildJson(values), "S" + op, prefix);
}

void ProducerTable::del(const string &key, const string &op, const string &prefix)
{
    enqueueDbChange(key, "{}", "D" + op, prefix);
}

void ProducerTable::enqueueDbChange(const string &key, const string &value, const string &op, const string& /* prefix */)
{
    RedisCommand command;

    command.format(
        "EVALSHA %s 2 %s %s %s %s %s %s",
        m_shaEnque.c_str(),
        getKeyValueOpQueueTableName().c_str(),
        getChannelName(m_pipe->getDbId()).c_str(),
        key.c_str(),
        value.c_str(),
        op.c_str(),
        "G");

    m_pipe->push(command, REDIS_REPLY_NIL);
}
```

On the other side, ConsumerTable is slightly more complicated because it supports many types of ops. The logic is written in a separate file (`common/consumer_table_pops.lua`). Interested readers can explore it further:

```cpp
// File: sonic-swss-common - common/consumertable.cpp
ConsumerTable::ConsumerTable(DBConnector *db, const string &tableName, int popBatchSize, int pri)
    : ConsumerTableBase(db, tableName, popBatchSize, pri)
    , TableName_KeyValueOpQueues(tableName)
    , m_modifyRedis(true)
{
    std::string luaScript = loadLuaScript("consumer_table_pops.lua");
    m_shaPop = loadRedisScript(db, luaScript);
    // ...
}

void ConsumerTable::pops(deque<KeyOpFieldsValuesTuple> &vkco, const string &prefix)
{
    // Note that here we are processing the messages in bulk with POP_BATCH_SIZE!
    RedisCommand command;
    command.format(
        "EVALSHA %s 2 %s %s %d %d",
        m_shaPop.c_str(),
        getKeyValueOpQueueTableName().c_str(),
        (prefix+getTableName()).c_str(),
        POP_BATCH_SIZE,

    RedisReply r(m_db, command, REDIS_REPLY_ARRAY);
    vkco.clear();

    // Parse and pack the messages in bulk
    // ...
}
```

## Monitor

To monitor how the `ProducerTable` and `ConsumerTable` work, we can use the `redis-cli monitor` command to see the actual Redis commands that being executed.

```bash
# Filter to `LPUSH` and `PUBLISH` commands to help us reduce the noise.
redis-cli monitor | grep -E "LPUSH|PUBLISH"
```

And here is an example of the output showing a `ProducerTable` enqueue operation:

```text
1735966216.139741 [1 lua] "LPUSH" "ASIC_STATE_KEY_VALUE_OP_QUEUE" "SAI_OBJECT_TYPE_SWITCH:oid:0x21000000000000" "[\"SAI_SWITCH_ATTR_AVAILABLE_IPV4_NEXTHOP_ENTRY\",\"1\"]" "Sget"               
1735966216.139774 [1 lua] "PUBLISH" "ASIC_STATE_CHANNEL@1" "G" 
```

# References

1. [SONiC Architecture][SONiCArch]  
2. [Github repo: sonic-swss][SONiCSWSS]  
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]  
4. [Redis keyspace notifications][RedisKeyspace]  
5. [Redis Transactions][RedisTx]  
6. [Redis Atomicity with Lua][RedisLuaAtomicity]  
7. [Redis hashes][RedisHash]  
8. [Redis client handling][RedisClientHandling]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common
[RedisKeyspace]: https://redis.io/docs/manual/keyspace-notifications/
[RedisTx]: https://redis.io/docs/manual/transactions/
[RedisLuaAtomicity]: https://developer.redis.com/develop/java/spring/rate-limiting/fixed-window/reactive-lua/
[RedisHash]: https://redis.io/docs/data-types/hashes/
[RedisClientHandling]: https://redis.io/docs/reference/clients/