FROM fedora:24

COPY suricata.repo /etc/yum.repos.d

RUN dnf -y --refresh install \
    suricata-3.1.1 \
    cronie \
    findutils \
    logrotate \
    python-pip \
    python-simplejson \
    supervisor \
    psmisc \
    tar && \
    dnf -y clean all && \
    find /var/log -type f -exec rm -f {} \;

# Install my own rule download tool, rulecat and seed the image with
# some rules.
# RUN pip install https://github.com/jasonish/py-idstools/archive/master.zip && \
#     idstools-rulecat --rules-dir /etc/suricata/rules

# Open up the permissions on /var/log/suricata so linked containers can
# see it.
RUN chmod 755 /var/log/suricata

COPY /etc /etc
COPY /docker-entrypoint.sh /
COPY /suricata-wrapper /usr/sbin/suricata-wrapper

VOLUME /var/log/suricata

RUN /usr/sbin/suricata -V

ENTRYPOINT ["/docker-entrypoint.sh"]
