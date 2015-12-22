FROM fedora:23

# Only enable when my copr repo has the newer stable build.
RUN dnf -y install 'dnf-command(copr)' && \
    dnf -y copr enable jasonish/suricata-stable && \
    dnf -y install \
    cronie \
    findutils \
    logrotate \
    python-pip \
    python-simplejson \
    supervisor \
    tar && \
    dnf -y install --best suricata-2.0.10 && \
    dnf -y clean all && \
    find /var/log -type f -exec rm -f {} \;

# Install my own rule download tool, rulecat and seed the image with
# some rules.
RUN pip install https://github.com/jasonish/py-idstools/archive/master.zip && \
    idstools-rulecat --rules-dir /etc/suricata/rules

# Open up the permissions on /var/log/suricata so linked containers can
# see it.
RUN chmod 755 /var/log/suricata

COPY /etc /etc
COPY /docker-entrypoint.sh /

VOLUME /var/log/suricata

ENTRYPOINT ["/docker-entrypoint.sh"]
