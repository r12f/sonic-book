# 命令行调用

SONiC中的与内核通信最简单的方式就是命令行调用了，其实现放在[common/exec.h](https://github.com/sonic-net/sonic-swss-common/blob/master/common/exec.h)文件下，且十分简单，接口如下：

```cpp
// File: common/exec.h
// Namespace: swss
int exec(const std::string &cmd, std::string &stdout);
```

其中，`cmd`是要执行的命令，`stdout`是命令执行的输出。这里的`exec`函数是一个同步调用，调用者会一直阻塞，直到命令执行完毕。其内部通过调用`popen`函数来创建子进程，并且通过`fgets`函数来获取输出。不过，**虽然这个函数返回了输出，但是基本上并没有人使用**，而只是通过返回值来判断是否成功，甚至连错误log中都不会写入输出的结果。

这个函数虽然粗暴，但是使用广泛，特别是在各个`*mgrd`服务中，比如`portmgrd`中就用它来设置每一个Port的状态等等。

```cpp
// File: sonic-swss - cfgmgr/portmgr.cpp
bool PortMgr::setPortAdminStatus(const string &alias, const bool up)
{
    stringstream cmd;
    string res, cmd_str;

    // ip link set dev <port_name> [up|down]
    cmd << IP_CMD << " link set dev " << shellquote(alias) << (up ? " up" : " down");
    cmd_str = cmd.str();
    int ret = swss::exec(cmd_str, res);

    // ...
```

```admonish note
**为什么说命令行调用是一种通信机制呢**？

原因是当`*mgrd`服务调用`exec`函数对系统进行的修改，会触发下面马上会提到的netlink事件，从而通知其他服务进行相应的修改，比如`*syncd`，这样就间接的构成了一种通信。所以这里我们把命令行调用看作一种通信机制能帮助我们以后更好的理解SONiC的各种工作流。
```

# 参考资料

1. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common