#! /bin/bash
#
# License: MIT

set -e
set -x

if [ "${REPO}" = "" ]; then
    REPO="docker.io/jasonish/suricata"
fi

MAJOR=$(basename $(pwd))
VERSION=$(cat VERSION)
LATEST=$(cat ../LATEST)

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
               --tag ${REPO}:${VERSION}-${arch} \
               -f Dockerfile.${arch} \
               .
}

for arch in ${archs[@]}; do
    build $arch
done

if [ "${push}" = "yes" ]; then
    for arch in ${archs[@]}; do
        docker push ${REPO}:${VERSION}-${arch}
    done
    
    # Create and push the manifest for the version.
    echo "Creating manifest: ${REPO}:${VERSION}"
    docker manifest create ${REPO}:${VERSION} \
           -a ${REPO}:${VERSION}-amd64 \
           -a ${REPO}:${VERSION}-arm32v6 \
           -a ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm --variant v6 \
           ${REPO}:${VERSION} ${REPO}:${VERSION}-arm32v6
    docker manifest annotate --arch arm --variant v8 \
           ${REPO}:${VERSION} ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm64 --variant v8 \
           ${REPO}:${VERSION} ${REPO}:${VERSION}-arm64v8
    docker manifest push --purge ${REPO}:${VERSION}
    
    # Create and push the manifest for the major version.
    docker manifest create ${REPO}:${MAJOR} \
           -a ${REPO}:${VERSION}-amd64 \
           -a ${REPO}:${VERSION}-arm32v6 \
           -a ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm --variant v6 \
           ${REPO}:${MAJOR} ${REPO}:${VERSION}-arm32v6
    docker manifest annotate --arch arm --variant v8 \
           ${REPO}:${MAJOR} ${REPO}:${VERSION}-arm64v8
    docker manifest annotate --arch arm64 --variant v8 \
           ${REPO}:${MAJOR} ${REPO}:${VERSION}-arm64v8
    docker manifest push --purge ${REPO}:${MAJOR}
    
    if [ "${MAJOR}" = "${LATEST}" ]; then
        for arch in ${archs[@]}; do
            docker tag ${REPO}:${VERSION}-${arch} ${REPO}:latest-${arch}
            docker push ${REPO}:latest-${arch}
        done
        docker manifest create ${REPO}:latest \
               -a ${REPO}:${VERSION}-amd64 \
               -a ${REPO}:${VERSION}-arm32v6 \
               -a ${REPO}:${VERSION}-arm64v8
        docker manifest annotate --arch arm --variant v6 \
               ${REPO}:latest ${REPO}:${VERSION}-arm32v6
        docker manifest annotate --arch arm --variant v8 \
               ${REPO}:latest ${REPO}:${VERSION}-arm64v8
        docker manifest annotate --arch arm64 --variant v8 \
               ${REPO}:latest ${REPO}:${VERSION}-arm64v8
        docker manifest push --purge ${REPO}:latest
    fi
fi
