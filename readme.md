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
  - Includes Nyx for monitoring and the Lyrebird obfs4proxy

## Usage  🐳

##### Via Docker Compose:

```yaml
services:
  tor:
    image: dockurr/tor
    container_name: tor
    ports:
      - 9050:9050
      - 9051:9051
    volumes:
      - ./config:/etc/tor
      - ./data:/var/lib/tor
    restart: always
```

##### Via Docker CLI:

```shell
docker run -it --rm --name tor -p 9050:9050 -p 9051:9051 -v "${PWD:-.}/config:/etc/tor" -v "${PWD:-.}/data:/var/lib/tor" docker.io/dockurr/tor
```

## Configuration 🔧

The container supports custom Tor configuration via mounted `torrc` file at `/etc/tor/torrc`.

**Environment Variables:**

- `TOR_CONTROL_ADDR` - Address of Tor Control Port (default: "127.0.0.1:9051")
  - Default connects to Tor instance within the same container
  - For external Tor server: `TOR_CONTROL_ADDR=192.168.1.100:9051`
  - Useful for monitoring remote relays or separate Tor containers

- `TOR_CONTROL_PASSWORD` - Password for Tor control port (default: "password")
  - The container automatically generates the required hash
  - Change this for production deployments
  - Example: `TOR_CONTROL_PASSWORD=mySecurePassword123`

- `DEBUG` - Enable debug output (default: "false")
  - Set to "true" for troubleshooting
  - Shows raw Tor Control Protocol responses

**Default Settings:**

- `SocksPort 0.0.0.0:9050` - SOCKS proxy enabled
- `ControlPort 127.0.0.1:9051` - Control port for healthcheck (container-local)
- `HashedControlPassword` - Generated automatically from `TOR_CONTROL_PASSWORD`

**Custom Configuration:**

You can provide your own `torrc` file with relay, exit node, or hidden service settings. The container will:
- Use your custom settings as the primary configuration
- Apply defaults only for options you don't specify
- Ensure required healthcheck settings are available

**Example with custom password:**

```yaml
services:
  tor:
    image: dockurr/tor
    environment:
      - TOR_CONTROL_PASSWORD=mySecurePassword123
    ports:
      - 9050:9050
    volumes:
      - ./config:/etc/tor
      - ./data:/var/lib/tor
```

**Example custom torrc:**

```
# Your relay configuration
Nickname MyTorRelay
ContactInfo your@email.com
ORPort 9050
DirPort 9030
ExitRelay 0
ExitPolicy reject *:*

# SocksPort and ControlPort are set by default if not specified
# To override, simply add your own settings here
```

## Development & Testing 🧪

**Testing the healthcheck locally:**

When testing `healthcheck/main.go` outside the container with `go run main.go`, you must set environment variables on your **host system** (not in compose.yml):

```bash
# Windows PowerShell
$env:TOR_CONTROL_PASSWORD="yourpassword"
go run healthcheck/main.go

# Windows CMD
set TOR_CONTROL_PASSWORD=yourpassword
go run healthcheck\main.go

# Linux/macOS
export TOR_CONTROL_PASSWORD=yourpassword
go run healthcheck/main.go
```

**Important:** compose.yml environment variables only apply **inside the container**. For full end-to-end testing, build and run the container:

```bash
docker compose build
docker compose up -d
docker compose logs -f tor
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
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Ftor%2Ftor.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
