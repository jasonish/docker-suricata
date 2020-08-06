#! /bin/bash

fix_perms() {
    if [[ "${PGID}" ]]; then
        groupmod -o -g "${PGID}" suricata
    fi

    if [[ "${PUID}" ]]; then
        usermod -o -u "${PUID}" suricata
    fi

    chown -R suricata:suricata /etc/suricata
    chown -R suricata:suricata /var/lib/suricata
    chown -R suricata:suricata /var/log/suricata
    chown -R suricata:suricata /var/run/suricata
}

for src in /etc/suricata.dist/*; do
    filename=$(basename ${src})
    dst="/etc/suricata/${filename}"
    if ! test -e "${dst}"; then
        echo "Creating ${dst}."
        cp -a "${src}" "${dst}"
    fi
    chown -R suricata:suricata /etc/suricata
done

fix_perms

# If the first command does not look like argument, assume its a
# command the user wants to run. Normally I wouldn't do this.
if [ $# -gt 0 -a "${1:0:1}" != "-" ]; then
    exec sudo -u suricata "$@"
fi

has_caps="yes"

check_for_cap() {
    echo -n "Checking for capability $1: "
    if getpcaps 1 2>&1 | grep -q "$1"; then
        echo "yes"
        return 0
    else
        echo "no"
        return 1
    fi
}

if ! check_for_cap cap_sys_nice; then
    has_caps="no"
fi
if ! check_for_cap cap_net_admin; then
    has_caps="no"
fi

args=()

if [[ "${has_caps}" != "yes" ]]; then
    echo "Warning: running as root due to missing capabilities" > /dev/stderr
else
    fix_perms
    args=(--user suricata --group suricata)
fi

if [-n "$SURICATA_OPTIONS"]
    exec /usr/bin/suricata "${args[@]}" $@ $SURICATA_OPTIONS
else
    exec /usr/bin/suricata "${args[@]}" $@
fi
