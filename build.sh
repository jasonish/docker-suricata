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

# Flag to enable pushing on individual image build.
do_push=no

build() {
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
    docker buildx build ${args[@]} \
           --load \
           --target runner \
           --build-arg CORES="${cores}" \
           --build-arg VERSION="${VERSION}" \
           --build-arg BUILD_DATE="$(date)" \
           -t ${NAME}:${VERSION}-${arch} \
           --platform ${platform} \
           -f Dockerfile.${arch} .

    if [ "${do_push}" = "yes" ]; then
        push_image ${NAME}:${VERSION}-${arch}
    fi
}

push_image() {
    image="$1"
    echo "Pushing ${image}"
    docker push ${image}
}

push() {
    # Push the individual images.
    push_image "${NAME}:${VERSION}-x86_64"
    push_image "${NAME}:${VERSION}-armv6"

    manifests=(${NAME}:${VERSION})
    if [[ "${TAG}" != "${VERSION}" ]]; then
        manifests+=(${NAME}:${TAG})
    fi
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

for arg in $@; do
    case "${arg}" in
        "--push")
            do_push="yes"
            shift
            ;;
    esac
done

case "$1" in
    x86_64|amd64)
        build x86_64
        ;;
    armv6)
        build armv6
        ;;
    manifest|push)
        push
        ;;
    all)
        build x86_64
        build armv6
        push
        ;;
esac
