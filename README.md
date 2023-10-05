# docker-tor-simple

[![build images](https://github.com/osminogin/docker-tor-simple/workflows/build%20images/badge.svg)](https://github.com/osminogin/docker-tor-simple/actions?query=workflow%3A%22build+images%22) [![](https://images.microbadger.com/badges/version/osminogin/tor-simple.svg)](https://microbadger.com/images/osminogin/tor-simple) [![latest version](https://github.com/osminogin/docker-tor-simple/actions/workflows/version.yml/badge.svg)](https://github.com/osminogin/docker-tor-simple/actions?query=workflow%3A%22latest+version%22) [![](https://img.shields.io/docker/stars/osminogin/tor-simple.svg)](https://hub.docker.com/r/osminogin/tor-simple) [![](https://images.microbadger.com/badges/image/osminogin/tor-simple.svg)](https://microbadger.com/images/osminogin/tor-simple) [![License: MIT](https://img.shields.io/badge/license-MIT-black.svg)](https://github.com/osminogin/docker-tor-simple/blob/master/LICENSE)

**Smallest minimal docker container for Tor network proxy daemon.**

Suitable for relay, exit node or hidden service modes with SOCKSv5 proxy enabled. It works well as a single self-contained container or in cooperation with other containers (like `nginx`) for organizing complex hidden services on the Tor network.

The image is based on great Alpine Linux distribution so it is has extremely low size (about 8 MB).

Service uses latest available version of [Tor package](https://pkgs.alpinelinux.org/package/edge/community/x86_64/tor) from [Edge repo](https://wiki.alpinelinux.org/wiki/Edge).

## Port

* `9050` SOCKSv5 (without auth)

## Volumes

* `/var/lib/tor` data dir.


## Getting started

### Installation

Automated builds of the image are available on [Docker Hub](https://hub.docker.com/r/osminogin/tor-simple/) and is the recommended method of installation.

```bash
docker pull osminogin/tor-simple
```

Alternatively you can build the image yourself.

```bash
export PROJECT_NAME=tor-node   # docker image name
make build DOCKER_IMAGE=$PROJECT_NAME
```


### Quickstart

```bash
export PROJECT_NAME=tor-local   # changing default name
make build DOCKER_IMAGE=$PROJECT_NAME
make run

# or with docker-compose ...
docker-compose up

# or altenativly run docker directly ...
docker run --publish 127.0.0.1:9050:9050 -i $PROJECT_NAME
```

After start Tor proxy available on `localhost:9050`

**Warning! Don't bind SOCKSv5 port 9050 to public network addresses if you don't know exactly what you are doing (is much better bind to `localhost` as in the example above)**.


## Advanced usage

You can copy original tor config from container, modify and mount them back inside. Changing the configuration file is required for running Tor as exit node, relay or bridge. For some operation modes you need to expose additional ports (9001, 9030, 9051).

```bash
# Copy config  from running container
docker cp tor:/etc/tor/torrc $HOME/torrc
# ... modify torrc and run again

# Start more complex example with updated config
docker run --rm --name tor \
  --publish 127.0.0.1:9050:9050 \
  --expose 9001 --publish 9001:9001 \ # ORPort
  --expose 9030 --publish 9030:9030 \
  --expose 9051 --publish 9051:9051 \
  --volume $HOME/torrc:/etc/tor/torrc:ro \
  osminogin/tor-simple
```

## Unit file for systemd

#### tor.service

```ini
[Unit]
Description=Tor service
Wants=network-online.target
Requires=docker.service
After=docker.service network.target network-online.target

[Service]
TimeoutStartSec=0
Restart=always
RestartSec=10s
ExecStartPre=/usr/bin/docker pull osminogin/tor-simple
ExecStart=/usr/bin/docker run --rm --name tor -p 127.0.0.1:9050:9050 osminogin/tor-simple
ExecStop=/usr/bin/docker stop tor

[Install]
WantedBy=multi-user.target
```


## Examples

Example webserver deployment config with microservice architecture to setup Tor hidden service.


#### docker-compose.yml

```yaml
version: '3.7'
services:

  tor-node:
    image: osminogin/tor-simple
    restart: always
    depends_on:
      - nginx

  nginx:
    image: nginx
    restart: always
```

## License

See [LICENSE](https://github.com/osminogin/docker-tor-simple/blob/master/LICENSE)
