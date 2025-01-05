# Command Line Invocation

The simplest way SONiC communicates with the kernel is through command-line calls, which are implemented in [common/exec.h](https://github.com/sonic-net/sonic-swss-common/blob/master/common/exec.h). The interface is straight-forward:

```cpp
// File: common/exec.h
// Namespace: swss
int exec(const std::string &cmd, std::string &stdout);
```

Here, `cmd` is the command to execute, and `stdout` captures the command output. The `exec` function is a synchronous call that blocks until the command finishes. Internally, it creates a child process via `popen` and retrieves output via `fgets`. However, **although this function returns output, it is rarely used in practice**. Most code only checks the return value for success, and sometimes even error logs won't be logged in the output.

Despite its simplicity, this function is widely used, especially in various `*mgrd` services. For instance, `portmgrd` calls it to set each port's status:

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
**Why is a command-line call considered a communication mechanism?**

Because when a `*mgrd` service modifies the system using `exec`, it triggers netlink events  (which will be mentioned in later chapters), notifying other services like `*syncd` to take corresponding actions. This indirect communication helps us better understand SONiC's workflows.
```

# References

1. [Github repo: sonic-swss-common][SONiCSWSSCommon]

[SONiCSWSSCommon]: https://github.com/sonic-net/sonic-swss-common