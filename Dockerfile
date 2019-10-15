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

RUN git clone https://github.com/OISF/suricata.git && \
        cd suricata && \
            git clone https://github.com/OISF/libhtp.git && \
        cd suricata-update && \
            curl -L \
            https://github.com/OISF/suricata-update/archive/master.tar.gz | \
              tar zxvf - --strip-components=1

WORKDIR /src/suricata
RUN ./autogen.sh
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
        python3-yaml \
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
