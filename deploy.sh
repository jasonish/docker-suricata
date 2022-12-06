#! /bin/bash

set -e

REPO=${REPO:-"docker.io/jasonish/suricata"}
MAJOR=$(basename $(pwd))
VERSION=$(cat VERSION)
LATEST=$(cat ../LATEST)
CORES=$(cat /proc/cpuinfo | grep ^processor | wc -l)
ARCHS=(amd64 arm64v8 arm32v6)
DOCKER=docker

args=()

while [ "$#" -gt 0 ]; do
    key="$1"
    case "${key}" in
        --podman)
            DOCKER="podman"
            ;;
        --build)
            build="yes"
            ;;
        --push)
            push="yes"
            ;;
        --manifest)
            manifest="yes"
            ;;
        -q|--quiet)
            docker_quiet="-q"
            ;;
        *)
            args+=($key)
            ;;
    esac
    shift
done

set -- "${args[@]}"

build() {
    arch="$1"; shift

    if ! test -e Dockerfile.${arch}; then
        echo "error: Dockerfile for arch ${arch} does not exist."
        exit 1
    fi

    configure_args=""

    tag="${REPO}:${VERSION}-${arch}"

    while [ "$#" -gt 0 ]; do
        next="$1"
        shift
        case "${next}" in
            profiling)
                configure_args="${configure_args} --enable-profiling --enable-profiling-locks"
                tag="${tag}-profiling"
                ;;
            *)
                echo "error: unhandled argument: ${next}"
                exit 1
                ;;
        esac
    done

    ${DOCKER} build --rm \
        ${docker_quiet} \
        --build-arg VERSION=${VERSION} \
        --build-arg CORES=${CORES} \
        --build-arg CONFIGURE_ARGS="${configure_args}" \
        --tag ${tag} \
        -f Dockerfile.${arch} \
        .

    if [ "${push}" = "yes" ]; then
        ${DOCKER} push ${tag}
    fi
}

manifest() {
    version="$1"
    variant="$2"
    ${DOCKER} manifest rm "${REPO}:${version}${variant}" > /dev/null 2>&1 || true
    for arch in "${ARCHS[@]}"; do
        if test -e Dockerfile.${arch}; then
            ${DOCKER} manifest create "${REPO}:${version}${variant}" \
                -a "${REPO}:${VERSION}-${arch}${variant}"
        fi
    done

    echo "Pushing manifest ${REPO}:${version}${variant}"
    if [ "${DOCKER}" = "docker" ]; then
        ${DOCKER} manifest push "${REPO}:${version}${variant}"
    elif [ "${DOCKER}" = "podman" ]; then
        ${DOCKER} manifest push --purge "${REPO}:${version}${variant}" \
            docker://"${REPO}:${version}${variant}"
    else
        echo "error: unsupported docker command: ${DOCKER}"
        exit 1
    fi
}
 
if [ "${build}" = "yes" ]; then
    if [ "$1" = "" ]; then
        for arch in "${ARCHS[@]}"; do
            if test -e Dockerfile.${arch}; then
                build "${arch}"
                build "${arch}" "profiling"
            fi
        done
    else
        build "${@}"
    fi
fi

if [ "${manifest}" = "yes" ]; then
    manifest ${VERSION}
    manifest ${VERSION} "-profiling"
    if [ "${MAJOR}" != "${VERSION}" ]; then
        manifest ${MAJOR}
        manifest ${MAJOR} "-profiling"
    fi
    if [ "${MAJOR}" = "${LATEST}" ]; then
        manifest latest
        manifest latest "-profiling"
    fi
fi
