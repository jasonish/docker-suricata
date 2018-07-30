FROM centos:7

RUN yum -y install epel-release yum-plugin-copr && \
    yum -y copr enable jasonish/suricata-stable && \
    yum -y install suricata-rust

# Open up the permissions on /var/log/suricata so linked containers can
# see it.
RUN chmod 755 /var/log/suricata

COPY /docker-entrypoint.sh /

VOLUME /var/log/suricata

RUN /usr/sbin/suricata -V

ENTRYPOINT ["/docker-entrypoint.sh"]
