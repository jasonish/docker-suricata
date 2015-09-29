#! /bin/sh

# If no arguments, bail.
if [ "$#" -eq 0 ]; then
    echo "Nothing to do."
    exit 1
fi

# Override PS1. It is likely this container may be run with host
# networking which will pick up the hosts name, and perhaps confuse
# the user when running a shell.
PS1="[docker:suricata \W]\\$ "

# If the first command does not look like argument, assume its a
# command the user wants to run. Normally I wouldn't do this.
if [ "${1:0:1}" != "-" ]; then
    PS1=${PS1} exec "$@"
fi

# Starting Suricata. We don't run it directly, but instead under
# supervisord so the container can be self-maintaining by rotating its
# own logs.

export SURICATA_ARGS="$@"
exec /usr/bin/supervisord -c /etc/supervisord.conf
