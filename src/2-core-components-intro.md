# Core components

We might feel that a switch is a simple network device, but in fact, there could be many components running on the switch.

Since SONiC decoupled all its services using Redis, it can be difficult to understand the relationships between services by simpling tracking the code. To get started on SONiC quickly, it is better to first establish a high-level model, and then delve into the details of each component. Therefore, before diving into other parts, we will first give a brief introduction to each component to help everyone build a rough overall model.

```admonish info
Before reading this chapter, there are two terms that will frequently appear in this chapter and in SONiC's official documentation: ASIC (Application-Specific Integrated Circuit) and ASIC state. They refer to the state of the pipeline used for packet processing in the switch, such as ACL or other packet forwarding methods.

If you are interested in learning more details, you can first read two related materials: [SAI (Switch Abstraction Interface) API][SAIAPI] and a related paper on RMT (Reprogrammable Match Table): [Forwarding Metamorphosis: Fast Programmable Match-Action Processing in Hardware for SDN][PISA].
```

In addition, to help us get started, we placed the SONiC architecture diagram here again as a reference:

![](assets/chapter-2/sonic-arch.png)

_(Source: [SONiC Wiki - Architecture][SONiCArch])_

# References

1. [SONiC Architecture][SONiCArch]
2. [SAI API][SAIAPI]
3. [Forwarding Metamorphosis: Fast Programmable Match-Action Processing in Hardware for SDN][PISA]

[SONiCArch]: https://github.com/sonic-net/SONiC/wiki/Architecture
[PISA]: http://yuba.stanford.edu/~grg/docs/sdn-chip-sigcomm-2013.pdf
[SAIAPI]: https://github.com/opencomputeproject/SAI/wiki/SAI-APIs