FROM fedora:23

# Only enable when my copr repo has the newer stable build.
RUN dnf -y install \
    cronie \
    findutils \
    logrotate \
    python-pip \
    python-simplejson \
    supervisor \
    tar \
    http://codemonkey.net/files/rpm/suricata/stable/fedora-23-x86_64/suricata-3.0-0.1.fc23.x86_64.rpm \
    && \
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

RUN /usr/sbin/suricata -V

ENTRYPOINT ["/docker-entrypoint.sh"]
