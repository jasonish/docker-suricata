#! /bin/sh
#
# Example of running the Suricata Docker image.
#
# Add -i <interface>.

docker run --rm -it \
       --name=suricata \
       --cap-add=sys_nice \
       --cap-add=net_admin \
       --net=host \
       jasonish/suricata:6.0 $@
