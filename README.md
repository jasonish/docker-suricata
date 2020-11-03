# Suricata Docker Image

## Usage

You will most likely want to run Suricata on a network interface on
your host machine rather than the network interfaces normally provided
inside a container:

    docker run --rm -it --net=host \
        --cap-add=net_admin --cap-add=sys_nice \
        jasonish/suricata:latest -i <interface>

But you will probably want to see what Suricata logs, so you may want
to start it like:

    docker run --rm -it --net=host \
        --cap-add=net_admin --cap-add=sys_nice \
        -v $(pwd)/logs:/var/log/suricata \
		jasonish/suricata:latest -i <interface>

which will map the logs directory (in your current directory) to the
Suricata log directory in the container so you can view the Suricata
logs from outside the container.

## Capabilities

This container will attempt to run Suricata as a non-root user
provided the containers has the capabilities to do so. In order to
monitor a network interface, and drop root privileges the container
must have the `sys_nice` and `net_admin` capabilities. If the
container detects that it does not have these capabilities, Suricata
will be run as root.

Docker example:

    docker run --rm -it --net=host \
        --cap-add=net_admin --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

Podman example:

    sudo podman run --rm -it --net=host \
        --cap-add=net_admin --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

## Docker Tags (Suricata Versions)

- master: The latest code from the git master branch.
- latest: The latest release version.
- 5.0: The latest 5.0 patch release.
- 4.1: The latest 4.1 patch release.

Specific version tags also exist for versions 4.1.5 and newer.

Examples:

    docker pull jasonish/suricata:latest
    docker pull jasonish/suricata:4.1
    docker pull jasonish/suricata:5.0.0

The images are rebuilt and pushed to Docker Hub daily to ensure they
are using the most up to date packages of the base OS, and in the case
of the `master` tag, to use the latest Suricata code for the git
master branch.

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

    docker run -e PUID=$(id -u) -e PGID=$(id-u)
    
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
        --cap-add=net_admin --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

## Suricata-Update

The easiest way to run Suricata-Update is to run it while the
container is running. For example:

In one terminal, start Suricata:

    docker run --name=suricata --rm -it --net=host \
        --cap-add=net_admin --cap-add=sys_nice \
        jasonish/suricata:latest -i eth0

Then in another terminal:

    docker exec -it --user suricata suricata suricata-update -f

The will execute `suricata-update` in the same container that is
running Suricata (note `--name=suricata`), then signal Suricata to
reload its rules with `suricatasc -c reload-rules`.

## Tools

### ./wrapper.py

`wrapper.py` is a script that wraps Suricata-in-Docker for use on the command
line as if it was installed locally.

`wrapper.py` has its own arguments that can be seen by running `wrapper.py -h`.
Arguments that occur after `--` are Suricata arguments and are passed directly
to Suricata (most of the time). The Suricata arguments are preprocessed to setup
any required volumes to provide the appearance that Suricata is running
directly.

#### Example: Run Suricata on a pcap file

```
./wrapper.py -- -r /path/to/filename.pcap
```

#### Example: Run Suricata 5.0.4 on network interface and log to current directory

```
./wrapper.py --tag 5.0.4 -- -i eno1 -l .
```

> Note that this tool is a work in process and may change, including a change of
> name.