# Getting Started with SONiC

## Why SONiC?

We know that switches have their own operating systems for configuration, monitoring and so on. However, since the first switch was introduced in 1986, despite ongoing development by various vendors, there are still some issues, such as:

1. Closed ecosystem: Non-open source systems primarily support proprietary hardware and are not compatible with devices from other vendors.
2. Limited use cases: It is difficult to use the same system to support complex and diverse scenarios in large-scale data centers.
3. Disruptive upgrades: Upgrades can cause network interruptions, which can be fatal for cloud providers.
4. Slow feature upgrades: It is challenging to support rapid product iterations due to slow device feature upgrades.

To address these issues, Microsoft initiated the SONiC open-source project in 2016. The goal was to create a universal network operating system that solves the aforementioned problems. Additionally, Microsoft's extensive use of SONiC in Azure ensures its suitability for large-scale production environments, which is another significant advantage.

## Architecture

SONiC is an open-source network operating system (NOS) developed by Microsoft based on Debian. It is designed with three core principles:

1. **Hardware and software decoupling**: SONiC abstracts hardware operations through the Switch Abstraction Interface (SAI), enabling SONiC to support multiple hardware platforms. SAI defines this abstraction layer, which is implemented by various vendors.
2. **Microservices with Docker containers**: The main functionalities of SONiC are divided into individual Docker containers. Unlike traditional network operating systems, upgrading the system can be done by upgrading specific containers without the need for a complete system upgrade or restart. This allows for easy upgrades, maintenance, and supports rapid development and iteration.
3. **Redis as a central database for service decoupling**: The configuration and status of most services are stored in a central Redis database. This enables seamless collaboration between services (data storage and pub/sub) and provides a unified method for operating and querying various services without concerns about data loss or protocol compatibility. It also facilitates easy backup and recovery of states.

These design choices gives SONiC a great open ecosystem ([Community][SONiCLanding], [Workgroups][SONiCWG], [Devices][SONiCDevices]). Overall, the architecture of SONiC is illustrated in the following diagram:

![](assets/chapter-1/sonic-arch.png)

_(Source: [SONiC Wiki - Architecture][SONiCArch])_

Of course, this design has some drawbacks, such as relative large disk usage. However, with the availability of storage space and various methods to address this issue, it is not a significant concern.

## Future Direction

Although switches have been around for many years, the development of cloud has raised higher demands and challenges for networks. These include intuitive requirements like increased bandwidth and capacity, as well as cutting-edge research such as in-band computing and edge-network convergence. These factors drive innovation among major vendors and research institutions. SONiC is no exception and continues to evolve to meet the growing demands.

To learn more about the future direction of SONiC, you can refer to its [Roadmap][SONiCPlanning]. If you are interested in the latest updates, you can also follow its workshops, such as the recent [OCP Global Summit 2022 - SONiC Workshop][SONiCWorkshop]. However, I won't go into detail here.

## Acknowledgments

Special thanks to the following individuals for their help and contributions. Without them, this introductory guide would not have been possible!

[@bingwang-ms](https://github.com/bingwang-ms)

# License

This book is licensed under the [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](https://creativecommons.org/licenses/by-nc-sa/4.0/).

# References

1. [SONiC Wiki - Architecture][SONiCArch]
2. [SONiC Wiki - Roadmap Planning][SONiCPlanning]
3. [SONiC Landing Page][SONiCLanding]
4. [SONiC Workgroups][SONiCWG]
5. [SONiC Supported Devices and Platforms][SONiCDevices]
6. [SONiC User Manual][SONiCManual]
7. [OCP Global Summit 2022 - SONiC Workshop][SONiCWorkshop]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[SONiCPlanning]: https://github.com/sonic-net/SONiC/wiki/Sonic-Roadmap-Planning
[SONiCLanding]: https://sonic-net.github.io/SONiC/index.html
[SONiCWG]: https://sonic-net.github.io/SONiC/workgroups.html
[SONiCDevices]: https://sonic-net.github.io/SONiC/Supported-Devices-and-Platforms.html
[SONiCManual]: https://github.com/sonic-net/SONiC/blob/master/doc/SONiC-User-Manual.md
[SONiCWorkshop]: https://www.youtube.com/playlist?list=PLAG-eekRQBSjwK0DpyHJs76gOz1619KqW