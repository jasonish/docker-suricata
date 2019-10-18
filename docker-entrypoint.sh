#! /bin/bash

# If the first command does not look like argument, assume its a
# command the user wants to run. Normally I wouldn't do this.
if [ "${1:0:1}" != "-" ]; then
    exec "$@"
fi

for src in /etc/suricata.dist/*; do
    filename=$(basename ${src})
    dst="/etc/suricata/${filename}"
    if ! test -e "${dst}"; then
        echo "Creating ${dst}."
        sudo cp -a "${src}" "${dst}"
    fi
    sudo chown -R suricata:suricata /etc/suricata
done

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
    args=(--user suricata --group suricata)
fi

exec sudo /usr/bin/suricata "${args[@]}" $@
