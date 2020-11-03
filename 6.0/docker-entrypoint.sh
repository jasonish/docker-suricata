#! /bin/sh

set -e

if [ "${TRACE}" != "" ]; then
    set -x
fi

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
done

# If the first command does not look like argument, assume its a
# command the user wants to run. Normally I wouldn't do this.
if [ $# -gt 0 -a "${1:0:1}" != "-" ]; then
    exec $@
fi

run_as_user="yes"

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

if ! check_for_cap sys_nice; then
    echo "Warning: no sys_nice capability, use --cap-add sys_nice"
    run_as_user="no"
fi
if ! check_for_cap net_admin; then
    echo "Warning: no net_admin capability, use --cap-add net_admin"
    run_as_user="no"
fi

ARGS=""

if [[ "${run_as_user}" != "yes" ]]; then
    echo "Warning: running as root due to missing capabilities" > /dev/stderr
else
    fix_perms
    ARGS="${ARGS} --user suricata --group suricata"
fi

exec /usr/bin/suricata ${ARGS} ${SURICATA_OPTIONS} $@
