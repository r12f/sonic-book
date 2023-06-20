# 编译

## 编译环境

由于SONiC是基于debian开发的，为了保证我们无论在什么平台下都可以成功的编译SONiC，并且编译出来的程序能在对应的平台上运行，SONiC使用了容器化的编译环境 —— 它将所有的工具和依赖都安装在对应debian版本的docker容器中，然后将我们的代码挂载进容器，最后在容器内部进行编译工作，这样我们就可以很轻松的在任何平台上编译SONiC，而不用担心依赖不匹配的问题，比如有一些包在debian里的版本比ubuntu更高，这样就可能导致最后的程序在debian上运行的时候出现一些意外的错误。

## 初始化编译环境

### 安装Docker

为了支持容器化的编译环境，第一步，我们需要保证我们的机器上安装了docker。

Docker的安装方法可以参考[官方文档][DockerInstall]，这里我们以Ubuntu为例，简单介绍一下安装方法。

首先，我们需要把docker的源和证书加入到apt的源列表中：

```bash
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

然后，我们就可以通过apt来快速安装啦：

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

安装完docker的程序之后，我们还需要把当前的账户添加到docker的用户组中，然后**退出并重新登录当前用户**，这样我们就可以不用sudo来运行docker命令了！**这一点非常重要**，因为后续SONiC的build是不允许使用sudo的。

```bash
sudo gpasswd -a ${USER} docker
```

安装完成之后，别忘了通过以下命令来验证一下是否安装成功（注意，此处不需要sudo！）：

```bash
docker run hello-world
```

### 安装其他依赖

```bash
sudo apt install -y python3-pip
pip3 install --user j2cli
```

### 拉取代码

在[3.1 代码仓库](./3-1-code-repos)一章中，我们提到了SONiC的主仓库是[sonic-buildimage][SonicBuildimageRepo]。它也是我们目前为止唯一需要安装关注的repo。

因为这个仓库通过submodule的形式将其他所有和编译相关的仓库包含在内，我们通过git命令拉取代码时需要注意加上`--recuse-submodules`的选项：

```bash
git clone --recurse-submodules https://github.com/sonic-net/sonic-buildimage.git
```

如果在拉取代码的时候忘记拉取submodule，可以通过以下命令来补上：

```bash
git submodule update --init --recursive
```

当代码下载完毕之后，或者对于已有的repo，我们就可以通过以下命令来初始化编译环境了。这个命令更新当前所有的submodule到需要的版本，以帮助我们成功编译：

```bash
sudo modprobe overlay
make init
```

## 了解并设置你的目标平台

[SONiC虽然支持非常多种不同的交换机][SONiCDevices]，但是由于不同型号的交换机使用的ASIC不同，所使用的驱动和SDK也会不同。SONiC通过SAI来封装这些变化，为上层提供统一的配置接口，但是在编译的时候，我们需要正确的设置好，这样才能保证我们编译出来的SONiC可以在我们的目标平台上运行。

现在，SONiC主要支持如下几个平台：

- barefoot
- broadcom
- marvell
- mellanox
- cavium
- centec
- nephos
- innovium
- vs

在确认好平台之后，我们就可以运行如下命令来配置我们的编译环境了：

```bash
make PLATFORM=<platform> configure
# e.g.: make PLATFORM=mellanox configure
```

```admonish note
<b>所有的make命令</b>（除了`make init`）一开始都会检查并创建所有debian版本的docker builder：bullseye，stretch，jessie，buster。每个builder都需要几十分钟的时间才能创建完成，这对于我们平时开发而言实在完全没有必要，一般来说，我们只需要创建最新的版本即可（当前为bullseye，bookwarm暂时还没有支持），具体命令如下：

    NOJESSIE=1 NOSTRETCH=1 NOBUSTER=1 make PLATFORM=<platform> configure

当然，为了以后开发更加方便，避免重复输入，我们可以将这个命令写入到`~/.bashrc`中，这样每次打开终端的时候，就会设置好这些环境变量了。

    export NOJESSIE=1
    export NOSTRETCH=1
    export NOBUSTER=1
```

## 编译代码

### 编译全部代码

设置好平台之后，我们就可以开始编译代码了：

```bash
# The number of jobs can be the number of cores on your machine.
# Say, if you have 16 cores, then feel free to set it to 16 to speed up the build.
make SONIC_BUILD_JOBS=4 all
```

```admonish note
当然，对于开发而言，我们可以把SONIC_BUILD_JOBS和上面其他变量一起也加入`~/.bashrc`中，减少我们的输入。

    export SONIC_BUILD_JOBS=<number of cores>
```

### 编译子项目代码

我们从SONiC的Build Pipeline中就会发现，编译整个项目是非常耗时的，而绝大部分时候，我们的代码改动只会影响很小部分的代码，所以有没有办法减少我们编译的工作量呢？答案是肯定的，我们可以通过指定make target来仅编译我们需要的子项目。

SONiC中每个子项目生成的文件都可以在`target`目录中找到，比如：

- Docker containers: target/<docker-image>.gz，比如：`target/docker-orchagent.gz`
- Deb packages: target/debs/<debian-version>/<package>.deb，比如：`target/debs/bullseye/libswsscommon_1.0.0_amd64.deb`
- Python wheels: target/python-wheels/<debian-version>/<package>.whl，比如：`target/python-wheels/bullseye/sonic_utilities-1.2-py3-none-any.whl`

当我们找到了我们需要的子项目之后，我们便可以将其生成的文件删除，然后重新调用make命令，这里我们用`libswsscommon`来举例子，如下：

```bash
# Remove the deb package for bullseye
rm target/debs/bullseye/libswsscommon_1.0.0_amd64.deb

# Build the deb package for bullseye
NOJESSIE=1 NOSTRETCH=1 NOBUSTER=1 make target/debs/bullseye/libswsscommon_1.0.0_amd64.deb
```

### 检查和处理编译错误

如果不巧在编译的时候发生了错误，我们可以通过检查失败项目的日志文件来查看具体的原因。在SONiC中，每一个子编译项目都会生成其相关的日志文件，我们可以很容易的在`target`目录中找到，如下：

```bash
$ ls -l
...
-rw-r--r--  1 r12f r12f 103M Jun  8 22:35 docker-database.gz
-rw-r--r--  1 r12f r12f  26K Jun  8 22:35 docker-database.gz.log      // Log file for docker-database.gz
-rw-r--r--  1 r12f r12f 106M Jun  8 22:44 docker-dhcp-relay.gz
-rw-r--r--  1 r12f r12f 106K Jun  8 22:44 docker-dhcp-relay.gz.log    // Log file for docker-dhcp-relay.gz
```

如果我们不想每次在更新代码之后都去代码的根目录下重新编译，然后查看日志文件，SONiC还提供了一个更加方便的方法，能让我们在编译完成之后停在docker builder中，这样我们就可以直接去对应的目录运行`make`命令来重新编译了：

```bash
# KEEP_SLAVE_ON=yes make <target>
KEEP_SLAVE_ON=yes make target/debs/bullseye/libswsscommon_1.0.0_amd64.deb
KEEP_SLAVE_ON=yes make all
```

```admonish note
有些仓库中的部分代码在全量编译的时候是不会编译的，比如，`sonic-swss-common`中的gtest，所以使用这种方法重编译的时候，请一定注意查看原仓库的编译指南，以避免出错，如：<https://github.com/sonic-net/sonic-swss-common#build-from-source>。
```

## 获取正确的镜像文件

编译完成之后，我们就可以在`target`目录中找到我们需要的镜像文件了，但是这里有一个问题：我们到底要用哪一种镜像来把SONiC安装到我们的交换机上呢？这里主要取决于交换机使用什么样的BootLoader或者安装程序，其映射关系如下：

| Bootloader | 后缀 |
| --- | --- |
| Aboot | .swi |
| ONIE | .bin |
| Grub | .img.gz |

## 部分升级

显然，在开发的时候，每次都编译安装镜像然后进行全量安装的效率是相当低下的，所以我们可以选择不安装镜像而使用直接升级deb包的方式来进行部分升级，从而提高我们的开发效率。

我们可以将deb包上传到交换机的`/etc/sonic`目录下，这个目录下的文件会被map到所有容器的`/etc/sonic`目录下，接着我们可以进入到容器中，然后使用`dpkg`命令来安装deb包，如下：

```bash
# Enter the docker container
docker exec -it <container> bash

# Install deb package
dpkg -i <deb-package>
```

# 参考资料

1. [SONiC Build Guide][SONiCBuild]
2. [Install Docker Engine][DockerInstall]
3. [Github repo: sonic-buildimage][SonicBuildimageRepo]
4. [SONiC Supported Devices and Platforms][SONiCDevices]
5. [Wrapper for starting make inside sonic-slave container][SONiCBuildImageMakeFile]

[SONiCBuild]: https://github.com/sonic-net/sonic-buildimage/blob/master/README.md
[DockerInstall]: https://docs.docker.com/engine/install/
[SonicBuildimageRepo]: https://github.com/sonic-net/sonic-buildimage
[SONiCDevices]: https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html
[SONiCBuildImageMakeFile]: https://github.com/sonic-net/sonic-buildimage/blob/master/Makefile.work