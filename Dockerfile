FROM fedora:27

RUN dnf -y --refresh install \
    	dnf-plugins-core \
	findutils && \
    dnf -y copr enable jasonish/suricata-stable && \
    dnf -y install --best suricata && \
    dnf -y clean all && \
    find /var/log -type f -delete

# Open up the permissions on /var/log/suricata so linked containers can
# see it.
RUN chmod 755 /var/log/suricata

COPY /docker-entrypoint.sh /

VOLUME /var/log/suricata

RUN /usr/sbin/suricata -V

ENTRYPOINT ["/docker-entrypoint.sh"]
