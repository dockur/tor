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

  - Intended to be used as a relay

## Usage  🐳

##### Via Docker CLI:

```shell
docker run --name tor-relay -p 9001:9001 -p 9030:9030 -v $(pwd)/data:/var/lib/tor tor-relay:latest
```

Users will need to create `data/` directory and own it with the `tor` user id
(100).

```shell
mkdir data/
sudo chown 100:100 ./data
```

[build_url]: https://github.com/dockur/tor/
[hub_url]: https://hub.docker.com/r/dockurr/tor/
[tag_url]: https://hub.docker.com/r/dockurr/tor/tags
[pkg_url]: https://github.com/dockur/tor/pkgs/container/tor

[Build]: https://github.com/dockur/tor/actions/workflows/build.yml/badge.svg
[Size]: https://img.shields.io/docker/image-size/dockurr/tor/latest?color=066da5&label=size
[Pulls]: https://img.shields.io/docker/pulls/dockurr/tor.svg?style=flat&label=pulls&logo=docker
[Version]: https://img.shields.io/docker/v/dockurr/tor/latest?arch=amd64&sort=semver&color=066da5
[Package]: https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fipitio.github.io%2Fbackage%2Fdockur%2Ftor%2Ftor.json&query=%24.downloads&logo=github&style=flat&color=066da5&label=pulls
