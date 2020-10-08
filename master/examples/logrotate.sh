#! /bin/sh
#
# Example of rotating the logs within the Suricata container.
#
# Add -v for verbose output.
# Add -f to force rotation.

docker exec suricata sudo logrotate /etc/logrotate.d/suricata $@

