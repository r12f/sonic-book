# Build

## Build Environment

To ensure that we can successfully build SONiC on any platform as well, SONiC leverages docker to build its build environment. It installs all tools and dependencies in a docker container of the corresponding Debian version, mounts its code into the container, and then start the build process inside the container. This way, we can easily build SONiC on any platform without worrying about dependency mismatches. For example, some packages in Debian have higher versions than in Ubuntu, which might cause unexpected errors during build time or runtime.

## Setup the Build Environment

### Install Docker

To support the containerized build environment, the first step is to ensure that Docker is installed on our machine.

You can refer to the [official documentation][DockerInstall] for Docker installation methods. Here, we briefly introduce the installation method for Ubuntu.

First, we need to add docker's source and certificate to the apt source list:

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

Then, we can quickly install docker via apt:

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

After installing docker, we need to add the current user to the docker user group and **log out and log back in**. This way, we can run any docker commands without sudo! **This is very important** because subsequent SONiC builds do not allow the use of sudo.

```bash
sudo gpasswd -a ${USER} docker
```

After installation, don't forget to verify the installation with the following command (note, no sudo is needed here!):

```bash
docker run hello-world
```

### Install Other Dependencies

```bash
sudo apt install -y python3-pip
pip3 install --user j2cli
```

### Pull the Code

In [Chapter 3.1 Code Repositories](./3-1-code-repos), we mentioned that the main repository of SONiC is [sonic-buildimage][SonicBuildimageRepo]. It is also the only repo we need to focus on for now.

Since this repository includes all other build-related repositories as submodules, we need to use the `--recurse-submodules` option when pulling the code with git:

```bash
git clone --recurse-submodules https://github.com/sonic-net/sonic-buildimage.git
```

If you forget to pull the submodules when pulling the code, you can make up for it with the following command:

```bash
git submodule update --init --recursive
```

After the code is downloaded, or for an existing repo, we can initialize the compilation environment with the following command. This command updates all current submodules to the required versions to help us successfully compile:

```bash
sudo modprobe overlay
make init
```

## Set Your Target Platform

[Although SONiC supports many different types of switches][SONiCDevices], different models of switches use different ASICs, which means different drivers and SDKs. Although SONiC uses SAI to hide these differences and provide a unified interface for the upper layers. However, we need to set target platform correctly to ensure that the right SAI will be used, so the SONiC we build can run on our target devices.

Currently, SONiC mainly supports the following platforms:

- broadcom
- mellanox
- marvell
- barefoot
- cavium
- centec
- nephos
- innovium
- vs

After confirming the target platform, we can configure our build environment with the following command:

```bash
make PLATFORM=<platform> configure
# e.g.: make PLATFORM=mellanox configure
```

```admonish note
<b>All make commands</b> (except `make init`) will first check and create all Debian version docker builders: `bookwarm`, `bullseye`, `stretch`, `jessie`, `buster`. Each builder takes tens of minutes to create, which is unnecessary for our daily development. Generally, we only need to create the latest version (currently `bookwarm`). The specific command is as follows:

        NO_BULLSEYE=1 NOJESSIE=1 NOSTRETCH=1 NOBUSTER=1 make PLATFORM=<platform> configure

To make future development more convenient and avoid entering these every time, we can set these environment variables in `~/.bashrc`, so that every time we open the terminal, they will be set automatically.

        export NOBULLSEYE=1
        export NOJESSIE=1
        export NOSTRETCH=1
        export NOBUSTER=1
```

## Build the Code

### Build All Code

After setting the platform, we can start compiling the code:

```bash
# The number of jobs can be the number of cores on your machine.
# Say, if you have 16 cores, then feel free to set it to 16 to speed up the build.
make SONIC_BUILD_JOBS=4 all
```

```admonish note
For daily development, we can also add SONIC_BUILD_JOBS and other variables above to `~/.bashrc`:

        export SONIC_BUILD_JOBS=<number of cores>
```

### Build Specific Package

From SONiC's Build Pipeline, we can see that compiling the entire project is very time-consuming. Most of the time, our code changes only affect a small part of the code. So, is there a way to reduce our compilation workload? Gladly, yes! We can specify the make target to build only the target or package we need.

In SONiC, the files generated by each subproject can be found in the `target` directory. For example:

- Docker containers: target/<docker-image>.gz, e.g., `target/docker-orchagent.gz`
- Deb packages: target/debs/<debian-version>/<package>.deb, e.g., `target/debs/bullseye/libswsscommon_1.0.0_amd64.deb`
- Python wheels: target/python-wheels/<debian-version>/<package>.whl, e.g., `target/python-wheels/bullseye/sonic_utilities-1.2-py3-none-any.whl`

After figuring out the package we need to build, we can delete its generated files and then call the make command again. Here we use `libswsscommon` as an example:

```bash
# Remove the deb package for bullseye
rm target/debs/bullseye/libswsscommon_1.0.0_amd64.deb

# Build the deb package for bullseye
make target/debs/bullseye/libswsscommon_1.0.0_amd64.deb
```

### Check and Handle Build Errors

If an error occurs during the build process, we can check the log file of the failed project to find the specific reason. In SONiC, each subproject generates its related log file, which can be easily found in the `target` directory, such as:

```bash
$ ls -l
...
-rw-r--r--  1 r12f r12f 103M Jun  8 22:35 docker-database.gz
-rw-r--r--  1 r12f r12f  26K Jun  8 22:35 docker-database.gz.log      // Log file for docker-database.gz
-rw-r--r--  1 r12f r12f 106M Jun  8 22:44 docker-dhcp-relay.gz
-rw-r--r--  1 r12f r12f 106K Jun  8 22:44 docker-dhcp-relay.gz.log    // Log file for docker-dhcp-relay.gz
```

If we don't want to check the log files every time, then fix errors and recompile in the root directory, SONiC provides another more convenient way that allows us to stay in the docker builder after build. This way, we can directly go to the corresponding directory to run the `make` command to recompile the things you need:

```bash
# KEEP_SLAVE_ON=yes make <target>
KEEP_SLAVE_ON=yes make target/debs/bullseye/libswsscommon_1.0.0_amd64.deb
KEEP_SLAVE_ON=yes make all
```

```admonish note
Some parts of the code in some repositories will not be build during full build. For example, gtest in `sonic-swss-common`. So, when using this way to recompile, please make sure to check the original repository's build guidance to avoid errors, such as: <https://github.com/sonic-net/sonic-swss-common#build-from-source>.
```

## Get the Correct Image File

After compilation, we can find the image files we need in the `target` directory. However, there will be many different types of SONiC images, so which one should we use? This mainly depends on what kind of BootLoader or Installer the switch uses. The mapping is as below:

| Bootloader | Suffix |
| --- | --- |
| Aboot | .swi |
| ONIE | .bin |
| Grub | .img.gz |

## Partial Upgrade

Obviously, during development, build the image and then performing a full installation each time is very inefficient. So, we could choose not to install the image but directly upgrading certain deb packages as partial upgrade, which could improving our development efficiency.

First, we can upload the deb package to the `/etc/sonic` directory of the switch. The files in this directory will be mapped to the `/etc/sonic` directory of all containers. Then, we can enter the container and use the `dpkg` command to install the deb package, as follows:

```bash
# Enter the docker container
docker exec -it <container> bash

# Install deb package
dpkg -i <deb-package>
```

# References

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