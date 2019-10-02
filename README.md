# Suricata Docker Image

## Usage

You will most likely want to run Suricata on a network interface on
your host machine rather than the network interfaces normally provided
inside a container:

    docker run -it --net=host --cap-add NET_ADMIN \
        jasonish/suricata:latest -i <interface>

But you will probably want to see what Suricata logs, so you may want
to start it like:

    docker run -it --net=host -v $(pwd)/logs:/var/log/suricata \
		jasonish/suricata:latest -i <interface>

which will map the logs directory (in your current directory) to the
Suricata log directory in the container so you can view the Suricata
logs from outside the container.

## Volumes

### /var/log/suricata

The directory /var/log/suricata is exposed as a volume. Another
container can attach it by using the --volumes-from Docker option.
For example:

- Start the Suricata container with a name:

    docker run -it --net=host --name=suricata jasonish/suricata -i enp3s0

- Start a second container with volumes-from:

    docker run -it --net=host --volumes-from=suricata logstash /bin/bash

This will expose /var/log/suricata from the Suricata container as
/var/log/suricata in the Logstash container.
