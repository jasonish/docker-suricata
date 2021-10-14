#! /bin/bash

set -e
set -x

NAME="jasonish/suricata"
MAJOR=$(basename $(pwd))
VERSION=$(cat VERSION)
LATEST=$(cat ../LATEST)

if [ "${HOST}" != "" ]; then
    NAME="${HOST}/${NAME}"
else
    HOST="docker.io"
fi

manifest_only="no"

builder="docker"
build_command="build"

# Handle command line arguments.
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
        --push)
            push="yes"
            shift
            ;;
        --no-cache)
            no_cache="--no-cache"
            shift
            ;;
        --manifest-only)
            manifest_only="yes"
            shift
            ;;
        --*)
            echo "error: bad argument: ${arg}"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

ARCHS=(amd64 arm32v6 arm64v8)
if [[ $# -gt 0 ]]; then
    archs=$@
else
    archs=${ARCHS[@]}
fi

if [[ "${manifest_only}" = "yes" ]]; then
    archs=""
fi

# Get the number of cores, defaulting to 2 if unable to get.
CORES=$(cat /proc/cpuinfo | grep ^processor | wc -l)
if [ "${CORES}" = "0" ]; then
    CORES=2
fi

build() {
    arch="$1"
    ${builder} ${build_command} \
               ${build_opts} ${no_cache} \
               --rm \
	       --build-arg VERSION="${VERSION}" \
               --build-arg CORES="${CORES}" \
               --tag ${NAME}:${VERSION}-${arch} \
               -f Dockerfile.${arch} \
               .
}

for arch in ${archs[@]}; do
    build $arch
done

if [ "${push}" = "yes" ]; then
    for arch in ${archs[@]}; do
        docker push ${NAME}:${VERSION}-${arch}
    done
    
    # Create and push the manifest for the version.
    echo "Creating manifest: ${NAME}:${VERSION}"
    docker manifest create ${NAME}:${VERSION} \
           -a ${NAME}:${VERSION}-amd64 \
           -a ${NAME}:${VERSION}-arm32v6 \
           -a ${NAME}:${VERSION}-arm64v8
    docker manifest annotate --arch arm --variant v6 \
           ${NAME}:${VERSION} ${NAME}:${VERSION}-arm32v6
    docker manifest annotate --arch arm --variant v8 \
           ${NAME}:${VERSION} ${NAME}:${VERSION}-arm64v8
    docker manifest annotate --arch arm64 --variant v8 \
           ${NAME}:${VERSION} ${NAME}:${VERSION}-arm64v8
    docker manifest push --purge ${NAME}:${VERSION}
    
    # Create and push the manifest for the major version.
    docker manifest create ${NAME}:${MAJOR} \
           -a ${NAME}:${VERSION}-amd64 \
           -a ${NAME}:${VERSION}-arm32v6 \
           -a ${NAME}:${VERSION}-arm64v8
    docker manifest annotate --arch arm --variant v6 \
           ${NAME}:${MAJOR} ${NAME}:${VERSION}-arm32v6
    docker manifest annotate --arch arm --variant v8 \
           ${NAME}:${MAJOR} ${NAME}:${VERSION}-arm64v8
    docker manifest annotate --arch arm64 --variant v8 \
           ${NAME}:${MAJOR} ${NAME}:${VERSION}-arm64v8
    docker manifest push --purge ${NAME}:${MAJOR}
    
    if [ "${MAJOR}" = "${LATEST}" ]; then
        for arch in ${archs[@]}; do
            docker tag ${NAME}:${VERSION}-${arch} ${NAME}:latest-${arch}
            docker push ${NAME}:latest-${arch}
        done
        docker manifest create ${NAME}:latest \
               -a ${NAME}:${VERSION}-amd64 \
               -a ${NAME}:${VERSION}-arm32v6 \
               -a ${NAME}:${VERSION}-arm64v8
        docker manifest annotate --arch arm --variant v6 \
               ${NAME}:latest ${NAME}:${VERSION}-arm32v6
        docker manifest annotate --arch arm --variant v8 \
               ${NAME}:latest ${NAME}:${VERSION}-arm64v8
        docker manifest annotate --arch arm64 --variant v8 \
               ${NAME}:latest ${NAME}:${VERSION}-arm64v8
        docker manifest push --purge ${NAME}:latest
    fi
fi
