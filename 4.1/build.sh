#! /bin/bash

set -e
set -x

NAME="jasonish/suricata"
MAJOR="4.1"
VERSION="4.1.8"

if [ "${HOST}" != "" ]; then
    NAME="${HOST}/${NAME}"
else
    HOST="docker.io"
fi

builder="docker"
build_command="build"

for arg in $@; do
    case "${arg}" in
        push|--push)
            push=yes
            ;;
        podman|--podman)
            builder="podman"
            ;;
        --no-cache)
            no_cache="--no-cache"
            ;;
        *)
            echo "error: bad argument: ${arg}"
            exit 1
    esac
done

case "${builder}" in
    podman)
        if [ "${push}" = "yes" ]; then
            echo "error: --push not supported with podman"
            exit 1
        fi
    ;;
    *)
    ;;
esac

# Get the number of cores, defaulting to 2 if unable to get.
cores=$(cat /proc/cpuinfo | grep ^processor | wc -l)
if [ "${cores}" = "0" ]; then
    cores=2
fi

${builder} ${build_command} \
           ${build_opts} ${no_cache} \
           --rm \
           --build-arg CORES="${cores}" \
           --tag ${NAME}:${VERSION}-amd64 \
           -f Dockerfile.centos-amd64 \
           .

${builder} ${build_command} \
           ${build_opts} ${no_cache} \
           --rm \
           --build-arg CORES="${cores}" \
           --tag ${NAME}:${VERSION}-arm32v6 \
           -f Dockerfile.alpine-arm32v6 \
           .

if [ "${push}" = "yes" ]; then
    if [ "${builder}" = "docker" ]; then
        docker push ${NAME}:${VERSION}-amd64
        docker push ${NAME}:${VERSION}-arm32v6
        
        # Create and push the manfest for the version.
        docker manifest create ${NAME}:${VERSION} \
               -a ${NAME}:${VERSION}-amd64 \
               -a ${NAME}:${VERSION}-arm32v6       
        docker manifest annotate --arch arm --variant v6 \
               ${NAME}:${VERSION} ${NAME}:${VERSION}-arm32v6
        docker manifest push --purge ${NAME}:${VERSION}

        # Create and push the manifest for the major version.
        docker manifest create ${NAME}:${MAJOR} \
               -a ${NAME}:${VERSION}-amd64 \
               -a ${NAME}:${VERSION}-arm32v6       
        docker manifest annotate --arch arm --variant v6 \
               ${NAME}:${MAJOR} ${NAME}:${VERSION}-arm32v6
        docker manifest push --purge ${NAME}:${MAJOR}
    else
        echo "error: push no implemented for ${builder}"
        exit 1
    fi
fi
