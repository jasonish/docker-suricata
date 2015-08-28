# Suricata Docker Image

## Usage

You will most likely want to run Suricata on a network interface on
your host machine rather than the network interfaces normally provided
inside a container:

    docker run -it --net=host jasonish/suricata -i <interface>

But you will probably want to see what Suricata logs, so you may want
to start it like:

    docker run -it --net=host -v $(pwd)/logs:/var/log/suricata -i <interface>

which will map the logs directory (in your current directory) to the
Suricata log directory in the container so you can view the Suricata
logs from outside the container.

## Configuration

Currently Suricata is seeded with the Emerging Threats open ruleset
when the container is created.

User level configuration is still a TODO. Of course you could map in
your own /etc/suricata and provide all required configuration files
and rules yourself.

