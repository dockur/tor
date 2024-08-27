<h1 align="center">Tor for Docker<br />
<div align="center">
<a href="https://github.com/dockur/tor"><img src="https://raw.githubusercontent.com/dockur/tor/master/.github/logo.png" title="Logo" style="max-width:100%;" width="256" /></a>
</div>
<div align="center">
  
[![Build]][build_url]
[![Version]][tag_url]
[![Size]][tag_url]
[![Package]][pkg_url]
[![Pulls]][hub_url]

</div></h1>

Docker container of the [Tor](https://www.torproject.org/) network proxy daemon.

## Features ✨

  - Suitable for relay, exit node or hidden service modes with SOCKSv5 proxy enabled.
  - Works well as a single self-contained container or in cooperation with other containers (like nginx) for organizing complex hidden services on the Tor network.

## Usage  🐳

Via Docker Compose:

```yaml
services:
  tor:
    container_name: tor
    image: dockurr/tor
    ports:
      - 9050:9050
      - 9051:9051
    volumes:
      - ./config:/etc/tor
      - ./data:/var/lib/tor
    stop_grace_period: 1m
```

Via Docker CLI:

```shell
docker run -it --rm -p 9050:9050 -p 9051:9051 dockurr/tor
```

## Stars 🌟
[![Stars](https://starchart.cc/dockur/tor.svg?variant=adaptive)](https://starchart.cc/dockur/tor)

[build_url]: https://github.com/dockur/tor/
[hub_url]: https://hub.docker.com/r/dockurr/tor/
[tag_url]: https://hub.docker.com/r/dockurr/tor/tags
[pkg_url]: https://github.com/dockur/tor/pkgs/container/tor

[Build]: https://github.com/dockur/tor/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/tor/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/tor.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/tor/latest?arch=amd64&sort=semver&color=066da5
[Package]: 
https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Ftor%2Ftor.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
