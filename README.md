# Suricata Docker Image

## Docker Tags (Suricata Versions)

- master: The latest code from the git master branch
- latest: The latest release version (currently 7.0)
- 7.0: The latest 7.0 patch release

Specific version tags also exist for versions 4.1.5 and newer.

Examples:

    docker pull jasonish/suricata:latest
    docker pull jasonish/suricata:6.0.15

Tags without an architecture like `amd64` or `arm64v8` are multi-architecture
image manifests. For the most part Docker will do the right thing, however if
you need to pull the image for a specific architecture you can do so by
selecting a tag with an architecture in the name, for example:

```
docker pull jasonish/suricata:latest-amd64
docker pull jasonish/suricata:6.0.4-arm64v8
```

## Alternate Registry

In addition to Docker Hub, these containers are also pushed to quay.io and can
be pulled like:

```
docker pull quay.io/jasonish/suricata:latest
```

## Usage

You will most likely want to run Suricata on a network interface on
your host machine rather than the network interfaces normally provided
inside a container:

    docker run --rm -it --net=host \
        --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
        jasonish/suricata:latest -i <interface>

But you will probably want to see what Suricata logs, so you may want
to start it like:

    docker run --rm -it --net=host \
        --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
        -v $(pwd)/logs:/var/log/suricata \
		jasonish/suricata:latest -i <interface>

which will map the logs directory (in your current directory) to the
Suricata log directory in the container so you can view the Suricata
logs from outside the container.

## Capabilities

This container will attempt to run Suricata as a non-root user provided the
containers has the capabilities to do so. In order to monitor a network
interface, and drop root privileges the container must have the `sys_nice`,
`net_admin`, and `net_raw` capabilities. If the container detects that it does
not have these capabilities, Suricata will be run as root.

Docker example:

    docker run --rm -it --net=host \
        --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

Podman example:

    sudo podman run --rm -it --net=host \
        --cap-add=net_admin,net_raw,sys_nice \
        jasonish/suricata:latest -i eth0

Note that with `podman` adding the capabilities is mandatory.

## Logging

The directory `/var/log/suricata` is exposed as a volume. Another
container can attach it by using the `--volumes-from` Docker option.
For example:

- Start the Suricata container with a name:

        docker run -it --net=host --name=suricata jasonish/suricata -i enp3s0

- Start a second container with `--volumes-from`:

        docker run -it --net=host --volumes-from=suricata logstash /bin/bash

This will expose `/var/log/suricata` from the Suricata container as
`/var/log/suricata` in the Logstash container.

## Log Rotation

Running `logrotate` inside the Suricata container will do the right thing, for
example:

```
docker exec CONTAINER_ID logrotate /etc/logrotate.d/suricata
```

to test, logrotate can run in a force and verbose mode:

```
docker exec CONTAINER_ID logrotate -vf /etc/logrotate.d/suricata
```

to run logrotate automatically set the `ENABLE_CRON=yes` environment
variable and create `suricata` bash script, with executable
permissions, in one of `/etc/cron.*` directories
(e.g. `/etc/cron.hourly/suricata`):

```
#! /bin/bash

logrotate /etc/logrotate.d/suricata
```

This script could be created in a `Dockerfile` using this one as a
base, or bind mounted in as a volume.

## Volumes

The Suricata container exposes the following volumes:

- `/var/log/suricata` - The Suricata log directory.
- `/var/lib/suricata` - Rules, Suricata-Update cache and other runtime
    data that may be useful to retain between runs.
- `/etc/suricata` - The configuration directory.

> Note: If `/etc/suricata` is a volume, it will be populated with a
> default configuration from the container.

If doing bind mounts you may want to have the Suricata user within the
container match the UID and GID of a user on the host system. This can
be done by setting the PUID and PGID environment variables. For
example:

    docker run -e PUID=$(id -u) -e PGID=$(id -g)
    
which will result in the bind mounts being owned by the user starting
the Docker container.

## Configuration

The easiest way to provide Suricata a custom configuration is to use a
host bind mount for the configuration directory, `/etc/suricata`. It
will be populated on the first run of the container. For example:

    mkdir ./etc
    docker run --rm -it -v $(pwd)/etc:/etc/suricata jasonish/suricata:latest -V

When the container exits, `./etc` will be populated with the default
configuration files normally found in `/etc/suricata`.

> Note: The files created in this directory will likely not be owned
> by the same uid as your host user, so you may need to use sudo to
> edit this files, or change their permissions.
>
> Hopefully this can be fixed.

In this directory the Suricata configuration can be modified, and
Suricata-Update files may be placed. It just needs to be provided as a
volume in subsequent runs of Suricata. For example:

    docker run --rm -it --net=host \
        -v $(pwd)/etc:/etc/suricata \
        --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

## Environment Variables

### SURICATA_OPTIONS

The `SURICATA_OPTIONS` environment variable can be used to pass command line
options to Suricata. For example:

```
docker run --net=host -e SURICATA_OPTIONS="-i eno1 -vvv" jasonish/suricata:latest
```

## Suricata-Update

The easiest way to run Suricata-Update is to run it while the
container is running. For example:

In one terminal, start Suricata:

    docker run --name=suricata --rm -it --net=host \
        --cap-add=net_admin --cap-add=net_raw --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

Then in another terminal:

    docker exec -it --user suricata suricata suricata-update -f

The will execute `suricata-update` in the same container that is
running Suricata (note `--name=suricata`), then signal Suricata to
reload its rules with `suricatasc -c reload-rules`.

## Raspberry Pi

This image is useable on the Raspberry Pi OS, however due to an
incompatibility between Raspberry Pi OS and Docker, the timestamps in
the logs will be wrong. There are 2 possible fixes to this issue:
- Use the `--privileged` option to Docker
- Upgrade the libseccomp2 package on Raspberry Pi OS to a newer
  version from the backports repo.

## HOWTOs

### Initialize a Configuration

Running with an empty volume at `/etc/suricata/suricata.yaml` will generate
default configuration files. Example:

```
docker run --rm -it -v $(pwd)/etc:/etc/suricata jasonish/suricata:latest -V
```

This will leave you with a directory containing the default configuration files
from the container.

## Building

The Dockerfiles and scripts in this repo are designed around building
multi-architecture container manifests in a somewhat automated
fashion. Due to this the Dockerfiles are not usable as-is.

### Building x86_64 (amd64) Images

If all you want to do is build an x86_64 image, the following commands
should work:

```
cd 7.0
../build.sh
```

If on ARM64:

```
cd 7.0
ARCH=arm64v8 ../build.sh
```

It is planned to keep the Dockerfiles in a state that are directly
usable without any wrapper scripts.

### Prepare to Build ARM images on x86_64

```
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

## License

The build scripts, Dockerfiles and any other files in this repo are MIT licensed.
