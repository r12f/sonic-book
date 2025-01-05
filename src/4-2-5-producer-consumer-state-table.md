# ProducerStateTable / ConsumerStateTable

Although `Producer/ConsumerTable` is straightforward and maintains the order of the messages, each message can only update one table key and requires JSON serialization. However, in many cases, we don't need strict ordering but need higher throughput. To optimize performance, SONiC introduces the fourth, and most frequently used, communication channel: [ProducerStateTable](https://github.com/sonic-net/sonic-swss-common/blob/master/common/producerstatetable.h) and [ConsumerStateTable](https://github.com/sonic-net/sonic-swss-common/blob/master/common/consumerstatetable.h).

## Overview

Unlike `ProducerTable`, `ProducerStateTable` uses a Hash to store messages instead of a List. This means the order of messages will not be guranteed, but it can significantly boosts performance:

- First, no more JSON serialization, hence its overhead is gone.
- Second, batch processing:
  - Multiple table updates can be merged into one (single pending update key set per table). 
  - If the same Field under the same Key is changed multiple times, only the latest change is preserved, merging all changes related to that Key into a single message and reducing unnecessary handling.

`Producer/ConsumerStateTable` is more complex under the hood than `Producer/ConsumerTable`. The related classes are shown in the diagram below, where `m_shaSet` and `m_shaDel` store the Lua scripts for modifying and sending messages, while `m_shaPop` is used to retrieve messages:

![](assets/chapter-4/producer-consumer-state-table.png)

## Sending messages

When sending messages:

1. Each message is stored in two parts:
   1. KEY_SET: keeps track of which Keys have been modified (stored as a Set at `<table-name_KEY_SET>`)
   2. A series of Hash: One Hash for each modified Key (stored at `_<redis-key-name>`).  
2. After storing a message, if the Producer finds out it's a new Key, it calls `PUBLISH` to notify `<table-name>_CHANNEL@<db-id>` that a new Key has appeared.

   ```cpp
   // File: sonic-swss-common - common/producerstatetable.cpp
   ProducerStateTable::ProducerStateTable(RedisPipeline *pipeline, const string &tableName, bool buffered)
       : TableBase(tableName, SonicDBConfig::getSeparator(pipeline->getDBConnector()))
       , TableName_KeySet(tableName)
       // ...
   {
       string luaSet =
           "local added = redis.call('SADD', KEYS[2], ARGV[2])\n"
           "for i = 0, #KEYS - 3 do\n"
           "    redis.call('HSET', KEYS[3 + i], ARGV[3 + i * 2], ARGV[4 + i * 2])\n"
           "end\n"
           " if added > 0 then \n"
           "    redis.call('PUBLISH', KEYS[1], ARGV[1])\n"
           "end\n";

       m_shaSet = m_pipe->loadRedisScript(luaSet);
   }
   ```

## Receiving messages

When receiving messages:

The consumer uses `SUBSCRIBE` to listen on `<table-name>_CHANNEL@<db-id>`. Once a new message arrives, it calls a Lua script to run `HGETALL`, fetch all Keys, and write them into the database.

```cpp
ConsumerStateTable::ConsumerStateTable(DBConnector *db, const std::string &tableName, int popBatchSize, int pri)
    : ConsumerTableBase(db, tableName, popBatchSize, pri)
    , TableName_KeySet(tableName)
{
    std::string luaScript = loadLuaScript("consumer_state_table_pops.lua");
    m_shaPop = loadRedisScript(db, luaScript);
    // ...

    subscribe(m_db, getChannelName(m_db->getDbId()));
    // ...
}
```

## Example

To illustrate, here is an example of enabling Port Ethernet0:

1. First, we call `config interface startup Ethernet0` from the command line to enable Ethernet0. This causes `portmgrd` to send a status update to APP_DB via ProducerStateTable, as shown below:

   ```redis
   EVALSHA "<hash-of-set-lua>" "6" "PORT_TABLE_CHANNEL@0" "PORT_TABLE_KEY_SET" 
       "_PORT_TABLE:Ethernet0" "_PORT_TABLE:Ethernet0" "_PORT_TABLE:Ethernet0" "_PORT_TABLE:Ethernet0" "G"
       "Ethernet0" "alias" "Ethernet5/1" "index" "5" "lanes" "9,10,11,12" "speed" "40000"
   ```

   This command triggers the following creation and broadcast:

   ```redis
   SADD "PORT_TABLE_KEY_SET" "_PORT_TABLE:Ethernet0"
   HSET "_PORT_TABLE:Ethernet0" "alias" "Ethernet5/1"
   HSET "_PORT_TABLE:Ethernet0" "index" "5"
   HSET "_PORT_TABLE:Ethernet0" "lanes" "9,10,11,12"
   HSET "_PORT_TABLE:Ethernet0" "speed" "40000"
   PUBLISH "PORT_TABLE_CHANNEL@0" "_PORT_TABLE:Ethernet0"
   ```

   Thus, the message is ultimately stored in APPL_DB as follows:

   ```redis
   PORT_TABLE_KEY_SET:
     _PORT_TABLE:Ethernet0

   _PORT_TABLE:Ethernet0:
     alias: Ethernet5/1
     index: 5
     lanes: 9,10,11,12
     speed: 40000
   ```

2. When ConsumerStateTable receives the message, it also calls `EVALSHA` to execute a Lua script, such as:

   ```redis
   EVALSHA "<hash-of-pop-lua>" "3" "PORT_TABLE_KEY_SET" "PORT_TABLE:" "PORT_TABLE_DEL_SET" "8192" "_"
   ```

   Similar to the Producer side, this script runs:

   ```redis
   SPOP "PORT_TABLE_KEY_SET" "_PORT_TABLE:Ethernet0"
   HGETALL "_PORT_TABLE:Ethernet0"
   HSET "PORT_TABLE:Ethernet0" "alias" "Ethernet5/1"
   HSET "PORT_TABLE:Ethernet0" "index" "5"
   HSET "PORT_TABLE:Ethernet0" "lanes" "9,10,11,12"
   HSET "PORT_TABLE:Ethernet0" "speed" "40000"
   DEL "_PORT_TABLE:Ethernet0"
   ```

   At this point, the data update is complete.

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