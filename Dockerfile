FROM fedora:30

RUN dnf -y update

RUN dnf -y install \
        autoconf \
        automake \
        cargo \
        file \
        file-devel \
        gcc \
        gcc-c++ \
        git \
        hiredis-devel \
        hyperscan-devel \
        jansson-devel \
        jq \
        lua-devel \
        libtool \
        libyaml-devel \
        libnfnetlink-devel \
        libnetfilter_queue-devel \
        libnet-devel \
        libcap-ng-devel \
        libevent-devel \
        libmaxminddb-devel \
        libpcap-devel \
        libprelude-devel \
        libtool \
        lz4-devel \
        make \
        nspr-devel \
        nss-devel \
        nss-softokn-devel \
        pcre-devel \
        pkgconfig \
        python3-devel \
        python3-yaml \
        rust \
        which \
        zlib-devel

WORKDIR /src

ENV VERSION 5.0.0
RUN curl -OL https://www.openinfosecfoundation.org/download/suricata-${VERSION}.tar.gz
RUN tar zxf suricata-${VERSION}.tar.gz

WORKDIR /src/suricata-${VERSION}

RUN ./configure \
        --prefix=/usr \
        --disable-shared \
        --disable-march-native \
        --enable-lua

ARG CORES=1

RUN make -j "${CORES}"

RUN make install install-conf DESTDIR=/fakeroot

FROM fedora:30

RUN dnf -y update && dnf -y install \
        file \
        findutils \
        hiredis \
        hyperscan \
        iproute \
        jansson \
        lua-libs \
        libyaml \
        libnfnetlink \
        libnetfilter_queue \
        libnet \
        libcap-ng \
        libevent \
        libmaxminddb \
        libpcap \
        libprelude \
        logrotate \
        lz4 \
        net-tools \
        nss \
        nss-softokn \
        pcre \
        procps-ng \
        python3-yaml \
        sudo \
        tcpdump \
        which \
        zlib \
        && dnf clean all

COPY --from=0 /fakeroot /
COPY /update.yaml /etc/suricata/update.yaml
COPY /docker-entrypoint.sh /
COPY /suricata.logrotate /etc/logrotate.d/suricata

RUN suricata-update update-sources && \
        suricata-update enable-source oisf/trafficid && \
        suricata-update --no-test --no-reload && \
        /usr/bin/suricata -V

RUN useradd --system --create-home suricata && \
        chown -R suricata:suricata /etc/suricata && \
        chown -R suricata:suricata /var/log/suricata && \
        chown -R suricata:suricata /var/lib/suricata && \
        chown -R suricata:suricata /var/run/suricata && \
        echo "suricata ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/suricata && \
        cp -a /etc/suricata /etc/suricata.dist && \
        chmod 600 /etc/logrotate.d/suricata

VOLUME /var/log/suricata
VOLUME /var/lib/suricata
VOLUME /etc/suricata

ENTRYPOINT ["/docker-entrypoint.sh"]
