# NotificationProducer / NotificationConsumer

When it comes to message communication, there is no way we can bypass message queues. And this is the second communication channel in SONiC - [NotificationProducer](https://github.com/sonic-net/sonic-swss-common/blob/master/common/notificationproducer.h) and [NotificationConsumer](https://github.com/sonic-net/sonic-swss-common/blob/master/common/notificationconsumer.h).

This communication channel is implemented using Redis's built-in PubSub mechanism, wrapping the `PUBLISH` and `SUBSCRIBE` commands. However, because `PUBLISH` needs everything being send to be serialized in the command, due to API limitations [\[5\]][RedisClientHandling], these commands are not suitable for passing large data. Hence, in SONiC, it is only used in limited places, such as simple notification scenarios (e.g., timeout checks or restart checks in orchagent), which won't have large payload, such as user configurations or data:

![](assets/chapter-4/notification-producer-consumer.png)

In this communication channel, the producer side performs two main tasks:

1. Package the message into JSON format.
2. Call Redis command `PUBLISH` to send it.

Because `PUBLISH` can only carry a single message, the "op" and "data" fields are placed at the front of "values", then the `buildJson` function is called to package them into a JSON array:

```cpp
int64_t swss::NotificationProducer::send(const std::string &op, const std::string &data, std::vector<FieldValueTuple> &values)
{
    // Pack the op and data into values array, then pack everything into a JSON string as the message
    FieldValueTuple opdata(op, data);
    values.insert(values.begin(), opdata);
    std::string msg = JSon::buildJson(values);
    values.erase(values.begin());

    // Publish message to Redis channel
    RedisCommand command;
    command.format("PUBLISH %s %s", m_channel.c_str(), msg.c_str());
    // ...
    RedisReply reply = m_pipe->push(command);
    reply.checkReplyType(REDIS_REPLY_INTEGER);
    return reply.getReply<long long int>();
}
```

The consumer side uses the `SUBSCRIBE` command to receive all notifications:

```cpp
void swss::NotificationConsumer::subscribe()
{
    // ...
    m_subscribe = new DBConnector(m_db->getDbId(),
                                    m_db->getContext()->unix_sock.path,
                                    NOTIFICATION_SUBSCRIBE_TIMEOUT);
    // ...

    // Subscribe to Redis channel
    std::string s = "SUBSCRIBE " + m_channel;
    RedisReply r(m_subscribe, s, REDIS_REPLY_ARRAY);
}
```

# References

1. [SONiC Architecture][SONiCArch]  
2. [Github repo: sonic-swss][SONiCSWSS]  
3. [Github repo: sonic-swss-common][SONiCSWSSCommon]  
4. [Redis keyspace notifications][RedisKeyspace]  
5. [Redis client handling][RedisClientHandling]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCSWSS]: https://github.com/sonic-net/sonic-swss
[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common
[RedisKeyspace]: https://redis.io/docs/manual/keyspace-notifications/
[RedisClientHandling]: https://redis.io/docs/reference/clients/