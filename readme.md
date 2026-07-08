<h1 align="center">Tor for Docker<br />
<div align="center">
<a href="https://github.com/dockur/tor"><img src="https://raw.githubusercontent.com/dockur/tor/master/.github/logo.png" title="Logo" style="max-width:100%;" width="128" /></a>
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

- Provides SOCKSv5 and HTTPS proxy access.
- Supports relay, exit node, bridge, and hidden service modes through custom configuration.
- Includes an extensive healthcheck, plus monitoring via [Nyx](https://nyx.torproject.org/) and pluggable transport support via Lyrebird.
- Lightweight Alpine-based image.

## Usage 🐳

##### Docker Compose:

```yaml
services:
  tor:
    image: dockurr/tor
    container_name: tor
    ports:
      - 9050:9050
      - 8118:8118
    restart: always
```

##### Docker CLI:

```shell
docker run -it --rm --name tor -p 9050:9050 -p 8118:8118 docker.io/dockurr/tor
```

The SOCKSv5 proxy is available on port `9050`, and the HTTPS proxy is available on port `8118`.

## Configuration 🔧

**Environment variables:**

- `PASSWORD` - Password for the Tor control port (default: "password")
  - Only used inside the container by the healthcheck. Change it if you plan to expose the control port (9051).

- `CHECK` - Enable external health checks (default: "false")
  - Set to "true" to also monitor the node status via external services like [https://check.torproject.org/](https://check.torproject.org/) and [Onionoo](https://onionoo.torproject.org).

- `DEBUG` - Enable debug output (default: "false")
  - Shows raw Tor Control Protocol responses.

**Advanced configuration:**

You can provide a custom Tor configuration file to the container via a `torrc` file in `/etc/tor`, with your own relay, exit node, bridge, or hidden service settings.

Mount the following directories in your compose file:

```yaml
volumes:
  - ./config:/etc/tor
  - ./data:/var/lib/tor
```

and place the custom `torrc` file in your `./config` directory, for example:

```torrc
# Your relay configuration
Nickname MyTorRelay
ContactInfo your@email.com
ORPort 9001
DirPort 9030
ExitRelay 0
ExitPolicy reject *:*
```

The `/var/lib/tor` directory contains Tor state and identity data. Persisting it is optional for simple proxy usage, but strongly recommended for relays and bridges because it preserves the relay identity and fingerprint.

## Stars 🌟

[![Stargazers](https://raw.githubusercontent.com/star-stats/stars/refs/heads/data/charts/dockur-tor.svg)](https://github.com/dockur/tor/stargazers)

[build_url]: https://github.com/dockur/tor/
[hub_url]: https://hub.docker.com/r/dockurr/tor/
[tag_url]: https://hub.docker.com/r/dockurr/tor/tags
[pkg_url]: https://github.com/dockur/tor/pkgs/container/tor

[Build]: https://github.com/dockur/tor/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/tor/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/tor.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/tor/latest?arch=amd64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Ftor%2Ftor.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
