FROM centos:7

COPY /jasonish-suricata-beta-epel-7.repo /etc/yum.repos.d/
RUN yum -y install suricata findutil && \
    yum clean all && \
    find /var/log -type f -exec rm -f {} \;

# Open up the permissions on /var/log/suricata so linked containers can
# see it.
RUN chmod 755 /var/log/suricata

COPY /docker-entrypoint.sh /

VOLUME /var/log/suricata

RUN /usr/sbin/suricata -V

ENTRYPOINT ["/docker-entrypoint.sh"]
