FROM fedora:25

RUN dnf -y install dnf-plugins-core
RUN dnf -y copr enable jasonish/suricata-stable
RUN dnf -y install --best suricata-3.2.2
RUN dnf -y --refresh install \
    findutils && \
    dnf -y clean all && \
    find /var/log -type f -exec rm -f {} \;

# Open up the permissions on /var/log/suricata so linked containers can
# see it.
RUN chmod 755 /var/log/suricata

COPY /docker-entrypoint.sh /

VOLUME /var/log/suricata

RUN /usr/sbin/suricata -V

ENTRYPOINT ["/docker-entrypoint.sh"]
