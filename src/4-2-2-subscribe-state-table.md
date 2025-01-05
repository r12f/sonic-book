# SubscribeStateTable

The most straight-forward redis-based communication channel is [SubscriberStateTable](https://github.com/sonic-net/sonic-swss-common/blob/master/common/subscriberstatetable.h).

The idea is to use the built-in keyspace notification mechanism of the Redis database [\[4\]][RedisKeyspace]. When any value in the Redis database changes, Redis sends two keyspace event notifications: one is `<op>` on `__keyspace@<db-id>__:<key>` and the other is `<key>` on `__keyevent@<db-id>__:<op>`. For example, deleting a key in database `0` triggers:

```redis
PUBLISH __keyspace@0__:foo del
PUBLISH __keyevent@0__:del foo
```

`SubscriberStateTable` listens for the first event notification and then calls the corresponding callback function. The main classes related to it are shown in this diagram, where we can see it inherits from ConsumerTableBase because it is a consumer of Redis messages:

![](assets/chapter-4/subscriber-state-table.png)

## Initialization

From the initialization code, we can see how it subscribes to Redis event notifications:

```cpp
// File: sonic-swss-common - common/subscriberstatetable.cpp
SubscriberStateTable::SubscriberStateTable(DBConnector *db, const string &tableName, int popBatchSize, int pri)
    : ConsumerTableBase(db, tableName, popBatchSize, pri), m_table(db, tableName)
{
    m_keyspace = "__keyspace@";
    m_keyspace += to_string(db->getDbId()) + "__:" + tableName + m_table.getTableNameSeparator() + "*";
    psubscribe(m_db, m_keyspace);
    // ...
```

## Event handling

`SubscriberStateTable` handles the event reception and distribution in two main functions:

- `readData()`: Reads pending events from Redis and puts them into the ConsumerTableBase queue  
- `pops()`: Retrieves the raw events from the queue, parses and passes them to the caller via function parameters

```cpp
// File: sonic-swss-common - common/subscriberstatetable.cpp
uint6464_t SubscriberStateTable::readData()
{
    // ...
    reply = nullptr;
    int status;
    do {
        status = redisGetReplyFromReader(m_subscribe->getContext(), reinterpret_cast<void**>(&reply));
        if(reply != nullptr && status == REDIS_OK) {
            m_keyspace_event_buffer.emplace_back(make_shared<RedisReply>(reply));
        }
    } while(reply != nullptr && status == REDIS_OK);
    // ...
    return 0;
}

void SubscriberStateTable::pops(deque<KeyOpFieldsValuesTuple> &vkco, const string& /*prefix*/)
{
    vkco.clear();
    // ...

    // Pop from m_keyspace_event_buffer, which is filled by readData()
    while (auto event = popEventBuffer()) {
        KeyOpFieldsValuesTuple kco;
        // Parsing here ...
        vkco.push_back(kco);
    }

    m_keyspace_event_buffer.clear();
}
```

# References

1. [SONiC Architecture][SONiCArch]  
2. [Github repo: sonic-swss][SONiCSWSS]  
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]  
4. [Redis keyspace notifications][RedisKeyspace]  

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common
[RedisKeyspace]: https://redis.io/docs/manual/keyspace-notifications/
