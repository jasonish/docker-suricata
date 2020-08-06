#! /bin/bash

set -e

NAME="jasonish/suricata"
TAG="5.0"
DOCKER="docker"
VERSION=$(cat VERSION)

# Get the number of cores, defaulting to 2 if unable to get.
cores=$(cat /proc/cpuinfo | grep ^processor | wc -l)
if [ "${cores}" = "0" ]; then
    cores=2
fi

deploy() {
    set -x
    arch="$1"

    case "${arch}" in
        x86_64)
            platform="linux/amd64"
            ;;
        armv6)
            platform="linux/arm/v6"
            ;;
        *)
            echo "error: bad platform: ${arch}"
            exit 1
            ;;
    esac

    args=()
    if [ "${BUILDER_TAG}" ]; then
        args+=(--cache-from=${BUILDER_TAG})
        args+=(--tag=${BUILDER_TAG})
    fi

    docker buildx build --target builder ${args[@]} \
           --load \
           --platform ${platform} \
           --build-arg CORES="${cores}" \
           --build-arg VERSION="${VERSION}" \
           -f Dockerfile.${arch} .

    args=()
    if [ "${BUILDER_TAG}" ]; then
        args+=(--cache-from=${BUILDER_TAG})
    fi
    if [ "${RUNNER_TAG}" ]; then
        args+=(--cache-from=${RUNNER_TAG})
    fi
    docker buildx build --rm ${args[@]} \
           --load \
           --target runner \
           --build-arg CORES="${cores}" \
           --build-arg VERSION="${VERSION}" \
           --build-arg BUILD_DATE="$(date)" \
           -t ${NAME}:${VERSION}-${arch} \
           --platform ${platform} \
           -f Dockerfile.${arch} .

    docker push ${NAME}:${VERSION}-${arch}
}

manifest() {
    manifests=(${NAME}:${VERSION} ${NAME}:${TAG})
    if test -e latest; then
        manifests+=(${NAME}:latest)
    fi
    for manifest in ${manifests[@]}; do
        docker manifest create ${manifest} \
               -a ${NAME}:${VERSION}-x86_64 \
               -a ${NAME}:${VERSION}-armv6
    done
    for manifest in ${manifests[@]}; do
        docker manifest push -p ${manifest}
    done
}

case "$1" in
    x86_64|amd64)
        deploy x86_64
        ;;
    armv6)
        deploy armv6
        ;;
    manifest)
        manifest
        ;;
    all)
        deploy x86_64
        deploy armv6
        manifest
        ;;
esac
