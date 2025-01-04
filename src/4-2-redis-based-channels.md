# Redis-based Channels

To facilitate communication between services, SONiC provides a messaging layer that is built on top of the Redis. On high-level, it contains 2 layers:

1. First layer wraps frequenctly used redis operations and provide table abstraction on top of it.
2. Second layer provides different channels for inter-service communication to satisfy various communication channel requirements.

Now, let's dive into them one by one.
