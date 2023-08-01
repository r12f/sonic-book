# Getting Started with SONiC

![Build Pipeline](https://img.shields.io/github/actions/workflow/status/r12f/sonic-book/mdbook.yml)

Version: [Chinese](https://r12f.com/sonic-book) | [English (Machine Translated, WIP)](https://r12f.com/sonic-book/en/)

> What is SONiC?
> 
> Software for Open Networking in the Cloud (SONiC) is an open source network operating system (NOS) based on Linux that runs on switches from multiple vendors and ASICs. SONiC offers a full suite of network functionality, like BGP and RDMA, that has been production-hardened in the data centers of some of the largest cloud service providers. It offers teams the flexibility to create the network solutions they need while leveraging the collective strength of a large ecosystem and community.
> 
> -- from [SONiC Foundation](https://sonicfoundation.dev/)

You might be interested in SONiC because it is powerful enough to suite your need, or maybe it looks pratical and promising enough due to the usage of Azure, or maybe its architecture is flexiable enough to allows you easily extend and satify your needs. However, you might found yourself lost in the ocean of documents and code - either because the documents being too high level and not hands-on enough or being too deep on each specific feature such as all the High Level Design docs. And now wondering how and where to actually start.

If you are in this situation, then this book is for you.

"Getting Started with SONiC" / "SONiC入门指南" is a book that intended to help people actually getting started on [SONiC](https://sonicfoundation.dev/). It contains a series of tutorials that will guide you through the process of building a SONiC image, deploying it on a switch or virtually, and using it to do some basic network operations to get hands on, as well as introducing the high level architecture, code base, and typical workflows to help you understand how it works internally and get started on development.

The book is currently in [Chinese（中文）](https://r12f.com/sonic-book) and English version is still working in progress. If you like this books, please give it a star, or join the effort of authoring, bug fixing or translations by submitting PRs.

## How to build

### Prerequisites

1. Install `just` by following the [installation guide](https://github.com/casey/just#installation). We use `just` instead of `make`, because it is easier to manage and use.
2. Install powershell by following the [installation guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3). This is because we use powershell as our make file script engine, so we can run our book on any platform. 
3. Run `just init` for installing mdbook and related pluins. This is one time initialization.

### Build

Simply run `just build` to build the book. The output will be in `book` folder.

### Serve

Run `just serve` to serve the book locally. You can then visit `http://localhost:3000` to view the book.

If we need to serve the book with specific translation, we can run `just po-serve <lang>`. For example, `just po-serve en` will serve the book in English.

## Acknowledgement

Huge thanks to the following friends for their help and contribution, without you there would be no this book!

[@bingwang-ms](https://github.com/bingwang-ms)

## License

This book is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).