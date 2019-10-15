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
        python-devel \
        python-yaml \
        rust \
        which \
        zlib-devel

WORKDIR /src

ENV VERSION 4.1.5
RUN curl -OL https://www.openinfosecfoundation.org/download/suricata-${VERSION}.tar.gz
RUN tar zxvf suricata-${VERSION}.tar.gz

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
        lz4 \
        net-tools \
        nss \
        nss-softokn \
        pcre \
        python-yaml \
        tcpdump \
        which \
        zlib \
        && dnf clean all

COPY --from=0 /fakeroot /

RUN cp -a /etc/suricata /etc/suricata.dist

RUN suricata-update update-sources && \
        suricata-update enable-source oisf/trafficid && \
        suricata-update --no-test --no-reload

VOLUME /var/log/suricata
VOLUME /var/lib/suricata
VOLUME /etc/suricata

RUN /usr/bin/suricata -V

COPY /docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
